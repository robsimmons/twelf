functor Compress (structure Global : GLOBAL) =
struct

  structure I = IntSyn
  structure S = Syntax
  structure Sgn = Sgn

  exception Unimp
  exception NoModes (* modes are not appropriate for the given I.ConDec *)

  val debug = ref ~1

(*  datatype Uni = Kind | Type

  datatype ConDec = ConDec of string * S.tp
		  | TyConDec of string * S.knd
		  | ConDef of string * S.term * S.tp
		  | AbbrevDef of string * S.term * S.tp

  val maxCid = Global.maxCid
  val dummyEntry = NONE
  val sgnArray = Array.array (maxCid+1, dummyEntry)
		 : ConDec option Array.array

  fun sgnClean i = if i >= maxCid then ()
                     else (Array.update (sgnArray, i, dummyEntry);
			   sgnClean (i+1)) 
	*)		  
  fun sgnReset () = Sgn.clear ()

(* xlate_type : IntSyn.Exp -> Syntax.tp *) 
  fun xlate_type (I.Pi ((I.Dec(_, e1), _), e2)) = S.TPi(S.MINUS, xlate_type e1, xlate_type e2)
    | xlate_type (I.Root (I.Const cid, sp)) = S.TRoot(cid, xlate_spine sp)
    | xlate_type (I.Root (I.Def cid, sp)) = S.TRoot(cid, xlate_spine sp) (* assuming cids of consts and defs to be disjoint *)
    | xlate_type (I.Root (I.NSDef cid, sp)) = S.TRoot(cid, xlate_spine sp)  (* ditto *)
    | xlate_type (I.Lam (_, t)) = xlate_type t  (* for type definitions, simply strip off the lambdas and leave
                                                   the variables free*)
  and xlate_spine I.Nil = []
    | xlate_spine (I.App(e, s)) = xlate_spinelt e :: xlate_spine s
  and xlate_spinelt e  = S.Elt(xlate_term e)
  and xlate_term (I.Root (I.Const cid, sp)) = S.ATerm(S.ARoot(S.Const cid, xlate_spine sp))
    | xlate_term (I.Root (I.Def cid, sp)) = S.ATerm(S.ARoot(S.Const cid, xlate_spine sp)) (* assuming cids of consts and defs to be disjoint *)
    | xlate_term (I.Root (I.NSDef cid, sp)) = S.ATerm(S.ARoot(S.Const cid, xlate_spine sp)) (* ditto *)
    | xlate_term (I.Root (I.BVar vid, sp)) = S.ATerm(S.ARoot(S.Var (vid - 1), xlate_spine sp))
    | xlate_term (I.Lam (_, e)) = S.NTerm(S.Lam (xlate_term e))
(* xlate_kind : IntSyn.Exp -> Syntax.knd *) 
  fun xlate_kind (I.Pi ((I.Dec(_, e1), _), e2)) = S.KPi(S.MINUS, xlate_type e1, xlate_kind e2)
    | xlate_kind (I.Uni(I.Type)) = S.Type

  val typeOf = S.typeOf
  val kindOf = S.kindOf

  exception Debug of S.spine * S.tp * S.tp
 (* val compress_type : Syntax.tp list -> Syntax.mode list option * Syntax.tp -> Syntax.tp *)
 (* the length of the mode list, if there is one, should correspond to the number of pis in the input type.
    however, as indicated in the XXX comment below, it seems necessary to treat SOME of empty list
    as if it were NONE. This doesn't seem right. *)
  fun compress_type G s = (* if !debug < 0 
			  then *) compress_type' G s 
			  (* else  (if !debug = 0 then raise Debug(G, s) else ();
				debug := !debug - 1; compress_type' G s) *) 
  and compress_type' G (NONE, S.TPi(_, a, b)) = S.TPi(S.MINUS, compress_type G (NONE, a), compress_type (a::G) (NONE, b))
    | compress_type' G (SOME (m::ms), S.TPi(_, a, b)) = S.TPi(m, compress_type G (NONE, a), compress_type (a::G) (SOME ms, b))
    | compress_type' G (SOME [], S.TRoot(cid, sp)) = S.TRoot(cid, compress_type_spine G (sp,
										   kindOf(Sgn.o_classifier cid), 
										   kindOf(Sgn.classifier cid)))
    | compress_type' G (NONE, a as S.TRoot _) = compress_type G (SOME [], a)
    | compress_type' G (SOME [], a as S.TPi _) = compress_type G (NONE, a) (* XXX sketchy *)

  and compress_type_spine G ([], w, wstar) = []
    | compress_type_spine G ((S.Elt m)::sp, S.KPi(_, a, v), S.KPi(mode, astar, vstar)) = 
      let
	  val mstar = compress_term G (m, a)
	  val sstar = compress_type_spine G (sp, 
					S.subst_knd (S.TermDot(m, a, S.Id)) v,
					S.subst_knd (S.TermDot(mstar, astar, S.Id)) vstar)
      in
	  case (mode, mstar) of
	      (S.OMIT, _) => S.Omit::sstar
	    | (S.MINUS, _) => S.Elt mstar::sstar
	    | (S.PLUS, S.ATerm t) => S.AElt t::sstar
	    | (S.PLUS, S.NTerm t) => S.Ascribe(t, compress_type G (NONE, a))::sstar
      end
  and compress_spine G ([], w, wstar) = []
    | compress_spine G ((S.Elt m)::sp, S.TPi(_, a, v), S.TPi(mode, astar, vstar)) = 
      let
	  val mstar = compress_term G (m, a)
	  val sstar = compress_spine G (sp, 
					S.subst_tp (S.TermDot(m, a, S.Id)) v,
					S.subst_tp (S.TermDot(mstar, astar, S.Id)) vstar)
      in
	  case (mode, mstar) of
	      (S.OMIT, _) => S.Omit::sstar
	    | (S.MINUS, _) => S.Elt mstar::sstar
	    | (S.PLUS, S.ATerm t) => S.AElt t::sstar
	    | (S.PLUS, S.NTerm t) => S.Ascribe(t, compress_type G (NONE, a))::sstar
      end
  and compress_term G (S.ATerm(S.ARoot(S.Var n, sp)), _) = 
      let
	  val a = S.ctxLookup(G, n)
	  val astar = compress_type G (NONE, a)
      in
	  S.ATerm(S.ARoot(S.Var n, compress_spine G (sp, a, astar)))
      end
    | compress_term G (S.ATerm(S.ARoot(S.Const n, sp)), _) = 
      let 
	  val a = typeOf (Sgn.o_classifier n)
	  val astar = typeOf (Sgn.classifier n)
	  val term_former = case Sgn.get_p n of
				SOME false => S.NTerm o S.NRoot
			      | _ => S.ATerm o S.ARoot
      in
	  term_former(S.Const n, compress_spine G (sp, a, astar))
      end
    | compress_term G (S.NTerm(S.Lam t),S.TPi(_, a, b)) = S.NTerm(S.Lam (compress_term (a::G) (t, b)))

  fun compress_kind G (NONE, S.KPi(_, a, k)) = S.KPi(S.MINUS, compress_type G (NONE, a), compress_kind (a::G) (NONE, k))
    | compress_kind G (SOME (m::ms), S.KPi(_, a, k)) = S.KPi(m, compress_type G (NONE, a), compress_kind (a::G) (SOME ms, k))
    | compress_kind G (SOME [], S.Type) = S.Type
    | compress_kind G (NONE, S.Type) = S.Type


(* compress : cid * IntSyn.ConDec -> ConDec *)		   
  fun compress (cid, IntSyn.ConDec (name, NONE, _, IntSyn.Normal, a, IntSyn.Type)) =
      let 
	  val x = xlate_type a
	  val modes = Sgn.get_modes cid
      in 
	  Sgn.condec(name, compress_type [] (modes, x), x) 
      end
    | compress (cid, IntSyn.ConDec (name, NONE, _, IntSyn.Normal, k, IntSyn.Kind)) = 
      let
	  val x = xlate_kind k
	  val modes = Sgn.get_modes cid
      in 
	  Sgn.tycondec(name, compress_kind [] (modes, x), x) 
      end
    | compress (cid, IntSyn.ConDef (name, NONE, _, m, a, IntSyn.Type)) = 
      let
	  val m = xlate_term m
	  val a = xlate_type a
	  val astar = compress_type [] (NONE, a)
	  val mstar = compress_term [] (m, astar)
      in 
	  Sgn.defn(name, astar, a, mstar, m) 
      end
    | compress (cid, IntSyn.ConDef (name, NONE, _, a, k, IntSyn.Kind)) = 
      let
	  val a = xlate_type a
	  val k = xlate_kind k
	  val kstar = compress_kind  [] (NONE, k)
	  val astar = compress_type (Syntax.explodeKind kstar) (NONE, a)
      in 
	  Sgn.tydefn(name, kstar, k, astar, a) 
      end
    | compress (cid, IntSyn.AbbrevDef (name, NONE, _, m, a, IntSyn.Type)) = 
      let
	  val m = xlate_term m
	  val a = xlate_type a
	  val astar = compress_type [] (NONE, a)
	  val mstar = compress_term [] (m, astar)
      in 
	  Sgn.abbrev(name, astar, a, mstar, m) 
      end
    | compress (cid, IntSyn.AbbrevDef (name, NONE, _, a, k, IntSyn.Kind)) = 
      let
	  val a = xlate_type a
	  val k = xlate_kind k
	  val kstar = compress_kind  [] (NONE, k)
	  val astar = compress_type (Syntax.explodeKind kstar) (NONE, a)
      in 
	  Sgn.tyabbrev(name, kstar, k, astar, a) 
      end
    | compress _ = raise Unimp

  fun sgnLookup (cid) = 
      let
	  val c = Sgn.sub cid
      in 
	  case c of NONE =>
		    let
			val c' = compress (cid, I.sgnLookup cid)
			val _ = Sgn.update (cid, c')
			val _ = print (Int.toString cid ^ "\n")
		    in
			c'
		    end
		  | SOME x => x
      end

 (*  val sgnApp  = IntSyn.sgnApp
	  
  fun sgnCompress () = sgnApp (ignore o sgnLookup) *)

  fun sgnCompressUpTo x = if x < 0 then () else (sgnCompressUpTo (x - 1); sgnLookup x; ())

  val check = Reductio.check

  fun extract f = ((f(); raise Match) handle Debug x => x)
		  
  val set_modes = Sgn.set_modes

(* val log : Sgn.sigent list ref = ref [] *)


  (* given a cid, pick some vaguely plausible omission modes *)
  fun naiveModes cid = 
      let
	  val (ak, omitted_args, uni) = 
	      case I.sgnLookup cid of
		  I.ConDec(name, package, o_a, status, ak, uni) => (ak, o_a, uni)
		| I.ConDef(name, package, o_a, ak, def, uni) => (ak, o_a, uni)
		| I.AbbrevDef(name, package, o_a, ak, def, uni) => (ak, o_a, uni)
		| _ => raise NoModes
	  fun count_args (I.Pi(_, ak')) = 1 + count_args ak'
	    | count_args _ = 0
	  val total_args = count_args ak

	  fun can_omit ms = 
	      let
		  val _ = Sgn.set_modes (cid, ms)
		  val s = compress (cid, I.sgnLookup cid)
		  val t = Sgn.typeOfSigent s
(*		  val _ = if true then log := !log @ [s] else () *)
		  val isValid = Reductio.check_plusconst_type t
(*		  val _ = if isValid then print "yup\n" else print "nope\n" *)
	      in
		  isValid
	      end

	  fun optimize' ms [] = rev ms
	    | optimize' ms (S.PLUS::ms') = if can_omit ((rev ms) @ (S.MINUS ::ms'))
					   then optimize' (S.MINUS::ms) ms' 
					   else optimize' (S.PLUS::ms) ms' 
	    | optimize' ms (S.MINUS::ms') = if  can_omit ((rev ms) @ (S.OMIT :: ms'))
					   then optimize' (S.OMIT::ms) ms'
					   else optimize' (S.MINUS::ms) ms'
	  fun optimize ms = optimize' [] ms
      in 
	  if uni = I.Kind
	  then List.tabulate (total_args, (fn _ => S.MINUS))
	  else optimize (List.tabulate (total_args, (fn x => if x < omitted_args then S.MINUS else S.PLUS)))
      end


  (* Given a cid, return the "ideal" modes specified by twelf-
     omitted arguments. It is cheating to really use these for
     compression: the resulting signature will not typecheck. *)
  fun idealModes cid = 
      let
	  val (ak, omitted_args) = 
	      case I.sgnLookup cid of
		  I.ConDec(name, package, o_a, status, ak, uni) => (ak, o_a)
		| I.ConDef(name, package, o_a, ak, def, uni) => (ak, o_a)
		| I.AbbrevDef(name, package, o_a, ak, def, uni) => (ak, o_a)
		| _ => raise Match
	  fun count_args (I.Pi(_, ak')) = 1 + count_args ak'
	    | count_args _ = 0
	  val total_args = count_args ak
      in 
	  List.tabulate (total_args, (fn x => if x < omitted_args then S.OMIT else S.MINUS))
      end

(* not likely to work if the mode-setting function f actually depends on
   properties of earlier sgn entries *)
  fun setModesUpTo x f = if x < 0 then () else (setModesUpTo (x - 1) f; 
						Sgn.set_modes (x, f x); ())

  fun sgnAutoCompress n f = (let 
      val modes = f n 
  in
      Sgn.set_modes(n, modes);  
      Sgn.update (n, compress (n, IntSyn.sgnLookup n))
  end handle NoModes => ())


  fun sgnAutoCompressUpTo' n0 n f =  
      if n0 > n
      then () 
      else let
	      val _ = 
                 (* has this entry already been processed? *)
		  case Sgn.sub n0 
		   of SOME _ => () 
                    (* if not, compress it *)
		    | NONE => 
		      let 
			  val modes = f n0
		      in 
			  (Sgn.set_modes(n0, modes); 
			   Sgn.update (n0, compress (n0, IntSyn.sgnLookup n0));
			   if n0 mod 100 = 0 then print (Int.toString n0 ^ "\n") else ())
		      end handle NoModes => ()
	  in
	      sgnAutoCompressUpTo' (n0 + 1) n f
	  end
  fun sgnAutoCompressUpTo n f = sgnAutoCompressUpTo' 0 n f

  val check = Reductio.check
end
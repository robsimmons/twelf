(* Gaussian-Elimination Equation Solver *)
(* Author: Roberto Virga *)

signature CS_EQ_INTEGERS =
sig
  include CS

  structure Integers : INTEGERS
  (*! structure IntSyn : INTSYN !*)

  (* Foreign expressions *)

  type 'a mset = 'a list                 (* MultiSet                   *)

  datatype Sum =                         (* Sum :                      *)
    Sum of Integers.int * Mon mset       (* Sum ::= m + M1 + ...       *)

  and Mon =                              (* Monomials:                 *)
    Mon of Integers.int * (IntSyn.Exp * IntSyn.Sub) mset
                                         (* Mon ::= n * U1[s1] * ...   *)

  val fromExp   : IntSyn.eclo -> Sum
  val toExp     : Sum -> IntSyn.Exp
  val normalize : Sum -> Sum

  val compatibleMon : Mon * Mon -> bool

  (* Internal expressions constructors *)

  val number     : unit -> IntSyn.Exp

  val unaryMinus : IntSyn.Exp -> IntSyn.Exp
  val plus       : IntSyn.Exp * IntSyn.Exp -> IntSyn.Exp
  val minus      : IntSyn.Exp * IntSyn.Exp -> IntSyn.Exp
  val times      : IntSyn.Exp * IntSyn.Exp -> IntSyn.Exp

  val constant   : Integers.int -> IntSyn.Exp
end  (* signature CS_EQ_FIELD *)

(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2011                                               *)
(*    CEA (Commissariat � l'�nergie atomique et aux �nergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Db
open Db_types
open Locations
open Visitor

let call_stack = Stack.create ()
exception Ignore

class do_it = object(self)
  inherit frama_c_inplace as super
  val mutable inputs = Zone.bottom

  method result = inputs

  method join new_ =
    inputs <- Zone.join new_ inputs;

  method vstmt_aux s =
    match s.skind with
      | UnspecifiedSequence seq ->
          List.iter
            (fun (stmt,_,_,_,_) ->
               ignore (visitFramacStmt (self:>frama_c_visitor) stmt))
            seq;
          Cil.SkipChildren (* do not visit the additional lvals *)
      | _ -> super#vstmt_aux s

  method vlval lv =
    let deps,loc =
      !Value.lval_to_loc_with_deps
        ~with_alarms:CilE.warn_none_mode
	~deps:Zone.bottom
	self#current_kinstr
	lv
    in
    let bits_loc = valid_enumerate_bits loc in
    self#join deps;
    self#join bits_loc;
    Cil.SkipChildren

  method do_assign lv =
    let deps,_loc =
      !Value.lval_to_loc_with_deps
        ~with_alarms:CilE.warn_none_mode
	~deps:Zone.bottom
	self#current_kinstr
	lv
    in
    (*      Format.printf "do_assign deps:%a@."
	    Zone.pretty deps; *)
    self#join deps;

  method vinst i =
    if Value.is_reachable (Value.get_state self#current_kinstr) then begin
      match i with
      | Set (lv,exp,_) ->
          self#do_assign lv;
          ignore (visitFramacExpr (self:>frama_c_visitor) exp);
          Cil.SkipChildren

      | Call (lv_opt,exp,args,_) ->
          (match lv_opt with None -> ()
           | Some lv -> self#do_assign lv);
          let deps_callees, callees =
            !Value.expr_to_kernel_function
              ~with_alarms:CilE.warn_none_mode
	      ~deps:(Some Zone.bottom)
	      self#current_kinstr exp
          in
          self#join deps_callees;
          Kernel_function.Hptset.iter
	    (fun kf -> self#join (!Db.Inputs.get_external kf))
	    callees;
          List.iter
	    (fun exp -> ignore (visitFramacExpr (self:>frama_c_visitor) exp))
	    args;
          Cil.SkipChildren
      | _ -> Cil.DoChildren
    end
    else Cil.SkipChildren

  method vexpr exp =
    match exp.enode with
    | AddrOf lv | StartOf lv ->
	let deps,_loc =
	  !Value.lval_to_loc_with_deps
            ~with_alarms:CilE.warn_none_mode
	    ~deps:Zone.bottom
	    self#current_kinstr lv
	in
	self#join deps;
	Cil.SkipChildren
    | _ -> Cil.DoChildren

end

let statement stmt =
  let computer = new do_it in
  ignore (visitFramacStmt (computer:>frama_c_visitor) stmt);
  computer#result

let expr stmt e =
  let computer = new do_it in
  computer#push_stmt stmt;
  ignore (visitFramacExpr (computer:>frama_c_visitor) e);
  computer#result

module Internals =
  Kf_state.Make
    (struct
       let name = "Internal inputs"
       let dependencies = [ Value.self ]
       let kind = `Correctness
     end)

let get_internal =
  Internals.memo
    (fun kf ->
       !Value.compute ();
       match kf.fundec with
       | Definition (f,_) ->
           (try
	      Stack.iter
		(fun g -> if kf == g then begin
                   Cil.warn
		     "recursive call detected during input analysis of %a. Ignoring it is safe if the value analysis suceeded without problem."
		     Kernel_function.pretty_name kf;
                   raise Ignore
                 end
		)
		call_stack;

	      (* No input to compute if the values were not computed for [kf] *)
	      (* if not (Value.is_accessible kf) then raise Ignore; *)

	      Stack.push kf call_stack;
	      let computer = new do_it in
	      ignore (visitFramacFunction (computer:>frama_c_visitor) f);
	      let _ = Stack.pop call_stack in
	      computer#result
	    with Ignore ->
	      Zone.bottom)
       | Declaration (_,_,_,_) ->
           let state = Value.get_initial_state kf in
           let behaviors = !Value.valid_behaviors kf state in
           let assigns = Ast_info.merge_assigns behaviors in
             !Value.assigns_to_zone_inputs_state state assigns)

module Externals =
  Kf_state.Make
    (struct
       let name = "External inputs"
       let dependencies = [ Internals.self ]
       let kind = `Correctness
     end)

let get_external =
  Externals.memo
    (fun kf ->
      Zone.filter_base
	(Db.accept_base ~with_formals:false kf)
	(get_internal kf))

let remove_locals_keep_formals fundec =
  match fundec with
  | Definition (fundec,_) ->
      Zone.filter_base
	 (fun v -> not (Base.is_local v fundec))
  | Declaration _ -> (fun v -> v)

module With_formals =
  Kf_state.Make
    (struct
       let name = "Inputs with formals"
       let dependencies = [ Internals.self ]
       let kind = `Correctness
     end)

let get_with_formals =
  Externals.memo
    (fun kf ->
      Zone.filter_base
	(Db.accept_base ~with_formals:true kf)
	(get_internal kf))

let compute_external kf = ignore (get_external kf)

let pretty_external fmt kf =
  Format.fprintf fmt "@[Inputs for function %a:@\n@[<hov 2>  %a@]@]@\n"
    Kernel_function.pretty_name kf
    Zone.pretty (get_external kf)

let pretty_with_formals fmt kf =
  Format.fprintf fmt "@[Inputs (with formals) for function %a:@\n@[<hov 2>  %a@]@]@\n"
    Kernel_function.pretty_name kf
    Zone.pretty (get_with_formals kf)

let () =
  Db.Inputs.self_internal := Internals.self;
  Db.Inputs.self_external := Externals.self;
  Db.Inputs.self_with_formals := With_formals.self;
  Db.Inputs.get_internal := get_internal;
  Db.Inputs.get_external := get_external;
  Db.Inputs.get_with_formals := get_with_formals;
  Db.Inputs.compute := compute_external;
  Db.Inputs.display := pretty_external;
  Db.Inputs.display_with_formals := pretty_with_formals;
  Db.Inputs.statement := statement;
  Db.Inputs.expr := expr

(*
Local Variables:
compile-command: "LC_ALL=C make -C ../.. -j"
End:
*)
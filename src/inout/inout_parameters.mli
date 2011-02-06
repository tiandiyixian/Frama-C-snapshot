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

include Plugin.S

module ForceAccessPath: Plugin.BOOL
(** undocumented *)

module ForceOut: Plugin.BOOL
module ForceExternalOut: Plugin.BOOL
module ForceInput: Plugin.BOOL
module ForceInputWithFormals: Plugin.BOOL
module ForceInout: Plugin.BOOL
module ForceInoutExternalWithFormals: Plugin.BOOL
module ForceDeref: Plugin.BOOL

(*
Local Variables:
compile-command: "LC_ALL=C make -C ../.."
End:
*)
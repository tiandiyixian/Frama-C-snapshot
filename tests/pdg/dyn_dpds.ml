(*
make -s tests/pdg/dyn_dpds.byte ; \
tests/pdg/dyn_dpds.byte -deps  tests/pdg/dyn_dpds.c; \
zgrviewer tests/pdg/dyn_dpds_1.dot ; \
zgrviewer tests/pdg/dyn_dpds_2.dot ;
*)

let get_zones str_data (kinst, kf) =
  let lval_term = !Db.Properties.Interp.lval kf kinst str_data in
  let lval = !Db.Properties.Interp.term_lval_to_lval ~result:None lval_term in
  let loc =
    !Db.From.find_deps_no_transitivity
      (Cil_types.Kstmt kinst)
      (Cil.new_exp ~loc:Cil_datatype.Location.unknown (Cil_types.Lval lval))
  in
  loc
;;

let main _ =
  let memo_debug = Kernel.Debug.get () in
  Kernel.Debug.set 1;
  let files = Ast.get () in
  Format.printf "@[%a@]" (Cil.d_file (new Printer.print ())) files;

  Kernel.Debug.set memo_debug ;

  let kf =  Globals.Functions.find_def_by_name "main" in
  let pdg = !Db.Pdg.get kf in

  !Db.Pdg.pretty Format.std_formatter pdg;
  !Db.Pdg.extract pdg "tests/pdg/dyn_dpds_0.dot";

  let assert_sid = 5 in (* assert ( *p>G) *)
  let assert_stmt, kf = Kernel_function.find_from_sid assert_sid in


  let _assert_node =
    match !Db.Pdg.find_simple_stmt_nodes pdg assert_stmt with
    | n::[] -> n | _ -> assert false
  in

  let star_p = get_zones "*p" (assert_stmt, kf) in
  let data_nodes, undef =
    !Db.Pdg.find_location_nodes_at_stmt pdg assert_stmt ~before:true star_p
  in

  assert (undef = None);

  let g_zone = get_zones "G" (assert_stmt, kf) in
  let g_nodes, undef =
    !Db.Pdg.find_location_nodes_at_stmt pdg assert_stmt ~before:true g_zone
  in

  let _data_nodes = g_nodes @ data_nodes in

  let undef = match undef with None -> assert false | Some z -> z in

  Format.printf "Warning : cannot select %a in this function...@\n"
    Locations.Zone.pretty undef;

  !Db.Pdg.pretty Format.std_formatter pdg;
  !Db.Pdg.extract pdg "tests/pdg/dyn_dpds_1.dot"

let () = Db.Main.extend main
open Core
open Codegen

(** Contains strings associated with operations such as migration and rollback *)
module MigrateOperations = struct
  module type Operation = sig
    val name : string
    (** The name used for the operation's query function and suffix for its script *)

    val operation_name : string
    (** The name used in printed messages in the operation's script *)
  end

  module Migrate = struct
    let name = "migrate"

    let operation_name = "Migration"
  end

  module Rollback = struct
    let name = "rollback"

    let operation_name = "Rollback"
  end
end

let make_migration_or_rollback_script module_name
    (module Operation : MigrateOperations.Operation) =
  Printf.sprintf
    {ocaml|
let result = Lwt_main.run (Db.execute @@ fun dbh -> Queries.%s.%s dbh ())

let () =
  match result with
  | Ok () -> print_endline "%s successful."
  | Error err ->
      print_endline "%s failed!" ;
      failwith (Caqti_error.show err)|ocaml}
    (String.capitalize module_name)
    Operation.name Operation.operation_name Operation.operation_name

(** [migration_operation_name "model" Rollback] returns ["model_rollback"] *)
let migration_script_name module_name
    (module Operation : MigrateOperations.Operation) =
  module_name ^ "_" ^ Operation.name

(* TODO - factor getting queries_name etc. out *)
let write_migration_script ~model_path ~reason
    (module Operation : MigrateOperations.Operation) =
  let module_name, dir = module_name_and_dir ~model_path in
  let queries_path =
    let basename =
      migration_script_name module_name (module Operation) ^ ".ml"
    in
    let ( / ) = Filename.concat in
    dir / ".." / "db" / "migrate" / basename
  in
  let script_content =
    make_migration_or_rollback_script module_name (module Operation)
  in
  let oc = Out_channel.create queries_path in
  Printf.fprintf oc "%s\n" script_content;
  Out_channel.close oc;
  Utils.reformat ~reason queries_path

let write_new_migrations_dune ~module_name ~dune_path =
  let dune_content =
    Printf.sprintf
      {dune|(executables
(names %s %s)
(libraries ocoi
           queries db))|dune}
      (migration_script_name module_name (module MigrateOperations.Migrate))
      (migration_script_name module_name (module MigrateOperations.Rollback))
  in
  let oc = Out_channel.create dune_path in
  Printf.fprintf oc "%s\n" dune_content;
  Out_channel.close oc

let update_migrations_dune ~module_name ~dune_path =
  let dune_lines = In_channel.read_lines dune_path in
  (* Should be "(names model1_migrate model1_rollback ...)" *)
  let names_line = List.nth_exn dune_lines 1 in
  let existing_names =
    List.tl_exn (List.t_of_sexp String.t_of_sexp (Sexp.of_string names_line))
  in
  let migrate_name =
    migration_script_name module_name (module MigrateOperations.Migrate)
  in
  let rollback_name =
    migration_script_name module_name (module MigrateOperations.Rollback)
  in
  let filtered_names =
    List.filter
      ~f:(fun w -> String.(w <> rollback_name && w <> migrate_name))
      existing_names
  in
  let new_names =
    ("names" :: filtered_names) @ [ migrate_name; rollback_name ]
  in
  let new_names_line =
    Sexp.to_string (List.sexp_of_t String.sexp_of_t new_names)
  in
  let new_lines =
    List.hd_exn dune_lines :: new_names_line :: List.slice dune_lines 2 0
  in
  let dune_content = String.concat ~sep:"\n" new_lines in
  let oc = Out_channel.create dune_path in
  Printf.fprintf oc "%s\n" dune_content;
  Out_channel.close oc

let create_or_update_migrate_dune ~model_path =
  let module_name, dir = module_name_and_dir ~model_path in
  let dune_path =
    let ( / ) = Filename.concat in
    dir / ".." / "db" / "migrate" / "dune"
  in
  match Sys.file_exists dune_path with
  | `Yes -> update_migrations_dune ~module_name ~dune_path
  | `No -> write_new_migrations_dune ~module_name ~dune_path
  | `Unknown -> failwith "Migrations dune file has unknown status"

let write_migration_scripts ~model_path ~reason =
  write_migration_script ~model_path ~reason (module MigrateOperations.Migrate);
  write_migration_script ~model_path ~reason (module MigrateOperations.Rollback);
  create_or_update_migrate_dune ~model_path

open Codegen
open Core

(* TODO - add tests *)

(** Given a list of resource attributes, return a string "column_name1, column_name2, ..."
 * (note the lack of parentheses). *)
let column_tuple_string resource_attributes =
  let joined_names =
    String.concat ~sep:", "
      (List.map resource_attributes ~f:(fun a -> a.sql_name))
  in
  joined_names

(** Generate the code to create the table for a resource. *)
let generate_create_table_sql table_name resource_attributes =
  let column_definitions =
    List.map resource_attributes ~f:(fun a ->
        a.sql_name ^ " " ^ a.sql_type_name)
  in
  let body = String.concat ~sep:",\n" column_definitions in
  Printf.sprintf {|CREATE TABLE %s (
%s
        )|} table_name
    (Utils.indent body ~filler:' ' ~amount:10)

(** Generate migrations code. *)
let make_migration_code ~table_name ~resource_attributes =
  let query = generate_create_table_sql table_name resource_attributes in
  Printf.sprintf
    {ocaml|let migrate =
  [%%rapper
    execute
      {sql|
       %s
      |sql}]

let rollback =
    [%%rapper
      execute
        {sql| DROP TABLE %s |sql}]
|ocaml}
    query table_name

type rapper_parameter = Input | Output

(** Generates code like [%int{id}, %string{name}] *)
let rapper_parameters kind resource_attributes =
  let symbol = match kind with Input -> "%" | Output -> "@" in
  let f { sql_name; name; rapper_name; _ } =
    let relevant_name = match kind with Input -> name | Output -> sql_name in
    Printf.sprintf "%s%s{%s}" symbol rapper_name relevant_name
  in
  List.map ~f resource_attributes |> String.concat ~sep:", "

(** Generates code like [name = %string{name}, age = %int{age}] *)
let rapper_update_set resource_attributes =
  let f { sql_name; rapper_name; name; _ } =
    Printf.sprintf "%s = %%%s{%s}" sql_name rapper_name name
  in
  List.map ~f resource_attributes |> String.concat ~sep:", "

(** Generate code for getting all instances of a resource. *)
let make_all_code ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let all =
  [%%rapper
    get_many
      {sql|
      SELECT %s
      FROM %s
      |sql}
      record_out]
|ocaml}
    (rapper_parameters Output resource_attributes)
    table_name

(** Generate model code for getting a resource instance by ID. *)
let make_show_code ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let show dbh id =
  [%%rapper
    get_opt
      {sql|
      SELECT %s
      FROM %s
      WHERE id = %%int{id}
      |sql} record_out]
  dbh ~id
|ocaml}
    (rapper_parameters Output resource_attributes)
    table_name

(* TODO - generalise id *)

(** Generate model code for creating a resource instance. *)
let make_create_code ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let create =
  [%%rapper
    get_one
      {sql|
      INSERT INTO %s (%s)
      VALUES (%s)
      RETURNING @int{id}
      |sql}]
|ocaml}
    table_name
    (column_tuple_string (without_id resource_attributes))
    (rapper_parameters Input (without_id resource_attributes))

(** Generate model code for updating resource instance. *)
let make_update_code ~table_name ~resource_attributes =
  Printf.sprintf
    {ocaml|let update =
  [%%rapper
    execute
      {sql|
      UPDATE %s
      SET %s
      WHERE id = %%int{id}
      |sql}
      record_in]
|ocaml}
    table_name
    (rapper_update_set resource_attributes)

(** Generate model code for destroying a resource instance. *)
let make_destroy_code ~table_name =
  Printf.sprintf
    {ocaml|let destroy dbh id =
  [%%rapper
    execute
      {sql| DELETE FROM %s WHERE id = %%int{id} |sql}]
  dbh ~id
|ocaml}
    table_name

let make_initial_code ~module_name =
  Printf.sprintf "open Core\nopen Models.%s" (String.capitalize module_name)

let write_queries ~model_path ~tree ~reason =
  let module_name, dir = module_name_and_dir ~model_path in
  let queries_path =
    let ( / ) = Filename.concat in
    dir / ".." / "queries" / (module_name ^ ".ml")
  in
  let oc = Out_channel.create queries_path in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  let table_name = Utils.pluralize module_name in
  let queries =
    [
      make_all_code ~table_name ~resource_attributes;
      make_show_code ~table_name ~resource_attributes;
      make_create_code ~table_name ~resource_attributes;
      make_update_code ~table_name ~resource_attributes;
      make_destroy_code ~table_name;
    ]
  in
  let initial_code = make_initial_code ~module_name in
  let crud_queries = String.concat ~sep:"\n\n" (initial_code :: queries) in
  let migration_queries =
    make_migration_code ~table_name ~resource_attributes
  in

  Printf.fprintf oc "%s\n%s\n" crud_queries migration_queries;
  Out_channel.close oc;
  Utils.reformat queries_path ~reason;
  let sql_migration_query =
    generate_create_table_sql table_name resource_attributes
  in
  let ( / ) = Filename.concat in
  let sql_migrations_dir = dir / ".." / "db" / "schema" in
  let sql_migration_path = sql_migrations_dir / (module_name ^ ".sql") in
  Unix.mkdir_p sql_migrations_dir;
  Out_channel.write_all ~data:sql_migration_query sql_migration_path

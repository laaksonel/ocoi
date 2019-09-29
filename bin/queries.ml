Caqti_request.collect Caqti_type.unit
    Caqti_type.(tup4 int string string int)
    {sql| SELECT id, username, email, coolness_rating FROM user |sql}

let all (module Db : Caqti_lwt.CONNECTION) =
  Db.fold all_query
    (fun (id, username, email, coolness_rating) acc ->
      {id; username; email; coolness_rating} :: acc)
    () []

let show_query =
  Caqti_request.find_opt Caqti_type.int
    Caqti_type.(tup4 int string string int)
    {sql| SELECT id, username, email, coolness_rating
       FROM user
       WHERE id = (?)
    |sql}

let show (module Db : Caqti_lwt.CONNECTION) id =
  let result = Db.find_opt show_query id in
  match%lwt result with
  | Ok data ->
      let record =
        match data with
        | Some (id, username, email, coolness_rating) -> Some {id; username; email; coolness_rating}
        | None -> None
      in
      Lwt.return record
  | Error _ -> failwith "Error in show query"

let create_query =
  Caqti_request.find
    Caqti_type.(tup3 string string int)
    Caqti_type.int
    {sql| INSERT INTO user (username, email, coolness_rating) VALUES (?, ?, ?) RETURNING id |sql}

let create (module Db : Caqti_lwt.CONNECTION) ~username ~email ~coolness_rating =
    Db.find create_query (username, email, coolness_rating)

let update_query =
  Caqti_request.exec
    Caqti_type.(tup4 string string int int)
    {| UPDATE user
       SET (username, email, coolness_rating) = (?, ?, ?)
       WHERE id = (?)
    |}

let update (module Db : Caqti_lwt.CONNECTION) id ~username ~email ~coolness_rating =
    Db.exec update_query (id, username, email, coolness_rating, id)

let destroy_query =
  Caqti_request.exec Caqti_type.int
    {sql| DELETE FROM user WHERE id = (?) |sql}

let destroy (module Db : Caqti_lwt.CONNECTION) id = Db.exec destroy_query id

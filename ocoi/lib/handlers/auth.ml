open Base
open Utils

type auth_credential = [ `Bearer of string | `Other of string ]

(** Helper to parse "Authorization: Bearer <credentials>" headers *)
let get_authorization header =
  let cohttp_parsed = Httpaf.Headers.get header "Authorization" in
  match cohttp_parsed with
  | Some content -> (
      match String.lsplit2 ~on:' ' content with
      | Some (type_, credentials) -> (
          match type_ with
          | "Bearer" -> Some (`Bearer credentials)
          | _ -> Some (`Other content) )
      | None -> Some (`Other content) )
  | None -> None

let get_bearer_token auth_value =
  match auth_value with Some (`Bearer t) -> Some t | _ -> None

let get_token ?auth_getter (req : Opium.Request.t) =
  let getter =
    match auth_getter with Some f -> f | None -> get_bearer_token
  in
  req.headers |> get_authorization |> getter

let authenticate ~check handler =
  let authenticated (req : Opium.Request.t) =
    let auth_header = req.headers |> get_authorization in
    match check auth_header req with
    | true -> handler req
    | false -> `String "" |> respond ~status:`Unauthorized
    (* TODO - determine whether 401 or 403 should be returned by default.*)
    (* TODO - possibly enable both 401 and 403 responses *)
  in
  authenticated

module Checks = struct
  let accept_all _ _ = true

  let reject_all _ _ = false

  let bearer_only token_check =
    let checker auth_header req =
      match auth_header with
      | Some (`Bearer token) -> token_check token req
      | _ -> false
    in
    checker

  let jwt ~jwk ~validate =
    let token_check token req =
      let verified = Jwt_utils.verify_and_decode ~jwk token in
      match verified with
      | Ok payload -> validate payload req
      | Error _ -> false
    in
    bearer_only token_check
end

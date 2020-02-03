(** Contains module types for defining responses of API endpoints, and modules that implement these types when relevant.

    For more details, see {!Handlers__.Responses.Make}.*)

open Base

type status_code
(** Represents an HTTP status code *)

(** Defines simple modules and module types that used as the basis for other response specification modules/types.

    For example, {!module-type:No_content} is an alias for {!module-type:Implementations.Unit}. *)
module Implementations : sig
  module type Unit = sig
    type t = unit
  end

  module Unit : sig
    type t = unit
  end

  module type Int = sig
    type t = int
  end

  module Int : sig
    type t = int
  end
end

(** For endpoints that return a piece of JSON *)
module type Json = sig
  type t

  val yojson_of_t : t -> Yojson.Safe.t
end

module type No_content = Implementations.Unit
(** For endpoints that return an empty response with a [204 No content] code *)

module No_content = Implementations.Unit

(** For endpoints that return an empty response and a [Location] header with a URL with a single path parameter *)
module Created : sig
  module type Int = Implementations.Int

  module Int = Implementations.Int
end

(* For endpoints that return an empty response with a certain status code *)
module type Empty_code = sig
  type t = status_code
end

module Empty_code : sig
  type t = status_code
end

(* For endpoints that return an empty response with a certain status code and set of headers *)
module type Empty_code_headers = sig
  type t = status_code * (string * string) sexp_list
end

module Empty_code_headers : sig
  type t = status_code * (string * string) sexp_list
end

(* For endpoints that return a string *)
module type String = sig
  type t = string
end

module String : sig
  type t = string
end

module type Json_list = Json
(** {!module-type:Json_list}, {!module-type:Json_opt} and {!module-type:Json_code} are aliases for {!module-type:Json},
 * and the functors with these names don't do anything. But they should still be used for endpoints will be used with
 * {!Handlers__.Responses.Make.Json_list} and similar for documentation purposes and to enable (currently hypothetical) *)

module type Json_opt = Json

module type Json_code = Json

module Json_list (Json : Json) : Json

module Json_opt (Json : Json) : Json

module Json_code (Json : Json) : Json

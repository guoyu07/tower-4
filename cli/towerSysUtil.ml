(*
 * Copyright (c) 2015 David Sheets <sheets@alum.mit.edu>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

let (  /  ) = Filename.concat
let ( $?. ) = Filename.check_suffix

let page_size = 4076 (* leave some space for metadata *)

let read_file f file =
  let ic = open_in_bin file in
  let pg = Bytes.create page_size in
  let rec read_more () =
    match input ic pg 0 page_size with
    | 0 -> ()
    | len -> f pg len; read_more ()
  in
  read_more ();
  close_in ic

let copy in_file out_file =
  let oc = open_out_bin out_file in
  read_file (fun buf len -> output oc buf 0 len) in_file;
  close_out oc

let buffer in_file =
  let buf = Buffer.create page_size in
  read_file (fun bytes len -> Buffer.add_subbytes buf bytes 0 len) in_file;
  buf

let rec read_files acc dh =
  match
    try Some (Unix.readdir dh)
    with End_of_file -> None
  with Some file -> read_files (file::acc) dh | None -> acc

let rec all_files base acc dh =
  let files = read_files [] dh in
  List.fold_left (fun acc -> function
  | "." | ".." -> acc
  | dirent ->
    let file = Filename.concat base dirent in
    try
      let dh = Unix.opendir file in
      let acc = all_files file acc dh in
      Unix.closedir dh;
      acc
    with
    | Unix.Unix_error (Unix.ENOTDIR, _, _) -> file::acc
    | Unix.Unix_error (Unix.ENOENT,  _, _) -> (* dangling symlink or race *)
      acc
  ) acc files

let in_dir path f =
  let cwd = Unix.getcwd () in
  Unix.chdir path;
  try let r = f () in Unix.chdir cwd; r
  with e -> Unix.chdir cwd; raise e

let foldp_paths f p acc dir =
  let dh = Unix.opendir dir in
  let files = in_dir dir (fun () -> all_files "" [] dh) in
  let () = Unix.closedir dh in
  List.fold_left (fun acc file ->
    if p file dir then f acc file else acc
  ) acc files

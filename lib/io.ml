(*
 * Copyright (C) 2006-2009 Citrix Systems Inc.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation; version 2.1 only. with the special
 * exception on linking described in file LICENSE.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *)

let (|||) a b = Int64.logor a b

(* read size bytes and return the completed buffer *)
let read fd size =
  let buf = String.create size in
  let i = ref size in
  while !i <> 0
  do
    let rd = Unix.read fd buf (size - !i) !i in
    if rd <= 0 then raise End_of_file;
    i := !i - rd
  done;
  buf

(** write a buf to fd *)
let write fd buf =
  let len = String.length buf in
  let i = ref len in
  while !i <> 0
  do
    let wd = Unix.write fd buf (len - !i) !i in
    i := !i - wd
  done

(** connect to the host and port, and give the fd *)
let connect host port =
  let sockaddr = Unix.ADDR_INET (host, port) in
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.connect fd sockaddr;
  fd

let byte_order_of_int ~endianness =
  match endianness with `big -> 0, 1, 2, 3 | `little -> 3, 2, 1, 0

let byte_order_of_int64 ~endianness =
  match endianness with
  | `big -> 0, 1, 2, 3, 4, 5, 6, 7
  | `little -> 7, 6, 5, 4, 3, 2, 1, 0

let marshall_int ~endianness x =
  let buffer = "\000\000\000\000" in
  let a, b, c, d = byte_order_of_int ~endianness in
  buffer.[a] <- char_of_int ((x lsr 24) land 0xff);
  buffer.[b] <- char_of_int ((x lsr 16) land 0xff);
  buffer.[c] <- char_of_int ((x lsr 8) land 0xff);
  buffer.[d] <- char_of_int ((x lsr 0) land 0xff);
  buffer

let write_int ~endianness fd x = write fd (marshall_int ~endianness x)

let marshall_int64 ~endianness x =
  let buffer = "\000\000\000\000\000\000\000\000" in
  let a, b, c, d, e, f, g, h = byte_order_of_int64 ~endianness in
  buffer.[a] <- char_of_int Int64.(to_int (logand (shift_right_logical x 56) 0xffL));
  buffer.[b] <- char_of_int Int64.(to_int (logand (shift_right_logical x 48) 0xffL));
  buffer.[c] <- char_of_int Int64.(to_int (logand (shift_right_logical x 40) 0xffL));
  buffer.[d] <- char_of_int Int64.(to_int (logand (shift_right_logical x 32) 0xffL));
  buffer.[e] <- char_of_int Int64.(to_int (logand (shift_right_logical x 24) 0xffL));
  buffer.[f] <- char_of_int Int64.(to_int (logand (shift_right_logical x 16) 0xffL));
  buffer.[g] <- char_of_int Int64.(to_int (logand (shift_right_logical x 8) 0xffL));
  buffer.[h] <- char_of_int Int64.(to_int (logand (shift_right_logical x 0) 0xffL));
  buffer

let write_int64 ~endianness fd x =
  write fd (marshall_int64 ~endianness x)

let unmarshall_int ~endianness buffer =
  let a, b, c, d = byte_order_of_int ~endianness in
  let a = int_of_char buffer.[a]
  and b = int_of_char buffer.[b]
  and c = int_of_char buffer.[c]
  and d = int_of_char buffer.[d] in
  (a lsl 24) lor (b lsl 16) lor (c lsl 8) lor d

let read_int ~endianness fd =
  let buffer = read fd 4 in
  unmarshall_int ~endianness buffer

let unmarshall_int64 ~endianness buffer =
  let a, b, c, d, e, f, g, h = byte_order_of_int64 ~endianness in
  let a = Int64.of_int (int_of_char buffer.[a])
  and b = Int64.of_int (int_of_char buffer.[b])
  and c = Int64.of_int (int_of_char buffer.[c])
  and d = Int64.of_int (int_of_char buffer.[d])
  and e = Int64.of_int (int_of_char buffer.[e])
  and f = Int64.of_int (int_of_char buffer.[f])
  and g = Int64.of_int (int_of_char buffer.[g])
  and h = Int64.of_int (int_of_char buffer.[h]) in
  Int64.((shift_left a 56) ||| (shift_left b 48) ||| (shift_left c 40) ||| (shift_left d 32) ||| (shift_left e 24) ||| (shift_left f 16) ||| (shift_left g 8) ||| h)

let read_int64 ~endianness fd =
  let buffer = read fd 8 in
  unmarshall_int64 ~endianness buffer

exception Integer_truncation
let int_of_int64_exn i64 =
  let i = Int64.to_int i64 in
  if Int64.of_int i = i64
  then i
  else raise Integer_truncation

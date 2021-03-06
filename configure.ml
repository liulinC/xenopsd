let config_mk = "config.mk"
let config_ml = "config.ml"

(* Configure script *)
open Cmdliner

let bindir =
  let doc = "Set the directory for installing binaries" in
  Arg.(value & opt string "/usr/bin" & info ["bindir"] ~docv:"BINDIR" ~doc)

let sbindir =
  let doc = "Set the directory for installing superuser binaries" in
  Arg.(value & opt string "/usr/sbin" & info ["sbindir"] ~docv:"SBINDIR" ~doc)

let libexecdir =
  let doc = "Set the directory for installing helper executables" in
  Arg.(value & opt string "/usr/lib/xenopsd" & info ["libexecdir"] ~docv:"LIBEXECDIR" ~doc)
let coverage =
  let doc = "Enable coverage profiling" in
  Arg.(value & flag & info ["enable-coverage"] ~doc)


let scriptsdir =
  let doc = "Set the directory for installing helper scripts" in
  Arg.(value & opt string "/usr/lib/xenopsd/scripts" & info ["scriptsdir"] ~docv:"SCRIPTSDIR" ~doc)

let etcdir =
  let doc = "Set the directory for installing configuration files" in
  Arg.(value & opt string "/etc" & info ["etcdir"] ~docv:"ETCDIR" ~doc)

let mandir =
  let doc = "Set the directory for installing manpages" in
  Arg.(value & opt string "/usr/share/man" & info ["mandir"] ~docv:"MANDIR" ~doc)

let optdir = 
  let doc = "Set the directory for installing system binaries" in
  Arg.(value & opt string "/opt/xensource/libexec" & info ["optdir"] ~docv:"OPTDIR" ~doc)

let info =
  let doc = "Configures a package" in
  Term.info "configure" ~version:"0.1" ~doc

let find_ocamlfind verbose name =
  let found =
    try
      let (_: string) = Findlib.package_property [] name "requires" in
      true
    with
    | Not_found ->
      (* property within the package could not be found *)
      true
    | Findlib.No_such_package(_,_ ) ->
      false in
  if verbose then Printf.fprintf stderr "querying for ocamlfind package %s: %s" name (if found then "ok" else "missing");
  found

let output_file filename lines =
  let oc = open_out filename in
  let lines = List.map (fun line -> line ^ "\n") lines in
  List.iter (output_string oc) lines;
  close_out oc

let find_ml_val verbose name libs =
  let ml_program = [
    Printf.sprintf "let f = %s" name;
  ] in
  let basename = Filename.temp_file "looking_for_val" "" in
  let ml_file = basename ^ ".ml" in
  let cmo_file = basename ^ ".cmo" in
  let cmi_file = basename ^ ".cmi" in
  output_file ml_file ml_program;
  let found = Sys.command (Printf.sprintf "ocamlfind ocamlc -package %s -c %s %s" (String.concat "," libs) ml_file (if verbose then "" else "2>/dev/null")) = 0 in
  if Sys.file_exists ml_file then Sys.remove ml_file;
  if Sys.file_exists cmo_file then Sys.remove cmo_file;
  if Sys.file_exists cmi_file then Sys.remove cmi_file;
  Printf.printf "Looking for %s: %s\n" name (if found then "ok" else "missing");
  found

let find_seriallist () =
  find_ml_val false "(Obj.magic 1 : Xenlight.Domain_build_info.type_hvm).Xenlight.Domain_build_info.serial_list" ["xenlight"]

let expand start finish input output =
  let command = Printf.sprintf "cat %s | sed -r 's=%s=%s=g' > %s" input start finish output in
  if Sys.command command <> 0
  then begin
    Printf.fprintf stderr "Failed to expand %s -> %s in %s producing %s\n" start finish input output;
    Printf.fprintf stderr "Command-line was:\n%s\n%!" command;
    exit 1;
  end

let output_file filename lines =
  let oc = open_out filename in
  List.iter (fun line -> Printf.fprintf oc "%s\n" line) lines;
  close_out oc

let find_xentoollog verbose =
  let c_program = [
    "int main(int argc, const char *argv){";
    "  return 0;";
    "}";
  ] in
  let c_file = Filename.temp_file "configure" ".c" in
  let exe_file = c_file ^ ".exe" in
  output_file c_file c_program;
  let found = Sys.command (Printf.sprintf "cc -Werror %s -lxentoollog -o %s %s" c_file exe_file (if verbose then "" else "2>/dev/null")) = 0 in
  if Sys.file_exists c_file then Sys.remove c_file;
  if Sys.file_exists exe_file then Sys.remove exe_file;
  Printf.printf "Looking for xentoollog: %s\n" (if found then "found" else "missing");
  output_file "xentoollog_flags" (if found then ["-L/lib64"; "-lxentoollog"] else []);
  found

let yesno_of_bool = function
  | true -> "YES"
  | false -> "NO"

let configure bindir sbindir libexecdir scriptsdir etcdir mandir optdir coverage =
  let xenctrl = find_ocamlfind false "xenctrl" in
  let xenlight = find_ocamlfind false "xenlight" in
  let xen45 = find_seriallist () in
  let xentoollog = find_xentoollog false in
  let p = Printf.sprintf in
  List.iter print_endline
    [ "Configure with"
    ; p "\tbindir=%s"     bindir
    ; p "\tsbindir=%s"    sbindir
    ; p "\tlibexecdir=%s" libexecdir
    ; p "\tscriptsdir=%s" scriptsdir
    ; p "\tetcdir=%s"     etcdir
    ; p "\tmandir=%s"     mandir
    ; p "\toptdir=%s"     optdir
    ; p "\txenctrl=%b"    xenctrl
    ; p "\txenlight=%b"   xenlight
    ; p "\txentoollog=%b" xentoollog
    ; p "\tcoverage=%b"   coverage
    ; p "" (* new line *)
    ];

  (* Write config.mk *)
  let lines =
    [ "# Warning - this file is autogenerated by the configure script";
      "# Do not edit";
      Printf.sprintf "BINDIR=%s" bindir;
      Printf.sprintf "SBINDIR=%s" sbindir;
      Printf.sprintf "LIBEXECDIR=%s" libexecdir;
      Printf.sprintf "SCRIPTSDIR=%s" scriptsdir;
      Printf.sprintf "ETCDIR=%s" etcdir;
      Printf.sprintf "MANDIR=%s" mandir;
      Printf.sprintf "OPTDIR=%s" optdir;
      Printf.sprintf "ENABLE_XEN=--%s-xen" (if xenctrl then "enable" else "disable");
      Printf.sprintf "ENABLE_XENLIGHT=--%s-xenlight" (if xenlight then "enable" else "disable");
      Printf.sprintf "ENABLE_XENTOOLLOG=--%s-xentoollog" (if xentoollog then "enable" else "disable");
      Printf.sprintf "BISECT_ENABLE=%s" (yesno_of_bool coverage);
      "export BISECT_ENABLE"
    ] in
  output_file config_mk lines;
  (* Expand @LIBEXEC@ in udev rules *)
  expand "@LIBEXEC@" libexecdir "scripts/vif.in" "scripts/vif";
  expand "@LIBEXEC@" libexecdir "scripts/xen-backend.rules.in" "scripts/xen-backend.rules";
  let configmllines =
    [ "(* Warning - this file is autogenerated by the configure script *)";
      "(* Do not edit *)";
      Printf.sprintf "#define xen45 %d" (if xen45 then 1 else 0) (* cppo is a bit broken *)
    ] in
  output_file config_ml configmllines

let configure_t = Term.(pure configure $ bindir $ sbindir $ libexecdir $ scriptsdir $ etcdir $ mandir $ optdir $ coverage)

let () =
  match
    Term.eval (configure_t, info)
  with
  | `Error _ -> exit 1
  | _ -> exit 0

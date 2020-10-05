open Import

module ShellPath = struct
  type t = string

  let ofJson json =
    let open Jsonoo.Decode in
    match string json with
    | exception Jsonoo.Decode_error _ -> Env.shell ()
    | "" -> Env.shell ()
    | shell -> shell

  let toJson (t : t) =
    let open Jsonoo.Encode in
    string t

  let key =
    let linux = "shell.linux" in
    let map =
      { Platform.Map.win32 = "shell.windows"
      ; darwin = "shell.osx"
      ; linux
      ; other = linux
      }
    in
    Platform.Map.find map Platform.t

  let t = Settings.create ~scope:Global ~key ~ofJson ~toJson
end

module ShellArgs = struct
  type t = string list option

  let ofJson json =
    let open Jsonoo.Decode in
    try_optional (list string) json

  let toJson (t : t) =
    let open Jsonoo.Encode in
    nullable (list string) t

  let key =
    let linux = "shellArgs.linux" in
    let map =
      { Platform.Map.win32 = "shellArgs.windows"
      ; darwin = "shellArgs.osx"
      ; linux
      ; other = linux
      }
    in
    Platform.Map.find map Platform.t

  let t = Settings.create ~scope:Global ~key ~ofJson ~toJson
end

let getShellPath () = Settings.get ~section:"ocaml.terminal" ShellPath.t

let getShellArgs () =
  let args section = Option.join (Settings.get ~section ShellArgs.t) in
  match args "ocaml.terminal" with
  | Some _ as s -> s
  | None -> args "terminal.integrated"

type t = Terminal.t

let create toolchain =
  let open Core_kernel.Option.Monad_infix in
  getShellPath () >>= fun shellPath ->
  getShellArgs () >>| fun shellArgs ->
  let ({ Cmd.bin; args } as command) =
    match Toolchain.getCommand toolchain shellPath shellArgs with
    | Spawn spawn -> spawn
    | Shell commandLine -> (
      match Platform.shell with
      | Sh bin -> { bin; args = [ "-c"; commandLine ] }
      | PowerShell bin -> { bin; args = [ "-c"; "& " ^ commandLine ] } )
  in
  Cmd.log (Spawn command);
  let packageManager = Toolchain.packageManager toolchain in
  let name = Toolchain.PackageManager.toPrettyString packageManager in
  let shellPath = Path.toString bin in
  let shellArgs = `Strings args in
  Window.createTerminal ~name ~shellPath ~shellArgs ()

let dispose = Terminal.dispose

let show t = Terminal.show t ()

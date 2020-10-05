open Import

let getFormatter toolchain ~document ~options:_ ~token:_ =
  let endLine = TextDocument.lineCount document - 1 in
  let endCharacter =
    TextDocument.lineAt document ~line:endLine |> TextLine.text |> String.length
  in
  (* selects entire document range *)
  let range =
    Range.makeCoordinates ~startLine:0 ~startCharacter:0 ~endLine ~endCharacter
  in
  (* text of entire document *)
  let documentText = TextDocument.getText document ~range () in
  let command = Toolchain.getDuneCommand toolchain [ "format-dune-file" ] in
  let output =
    let open Promise.Result.Syntax in
    Cmd.check command >>= fun command -> Cmd.output ~stdin:documentText command
  in
  let open Promise.Syntax in
  `Promise
    (output >>| function
     | Ok newText -> Some [ TextEdit.replace ~range ~newText ]
     | Error msg ->
       message `Error "Dune formatting failed: %s" msg;
       Some [])

type t = Disposable.t list ref

let create () = ref []

let register t toolchain =
  t :=
    [ "dune"; "dune-project"; "dune-workspace" ]
    |> List.map (fun language ->
           let selector =
             `Filter (DocumentFilter.create ~scheme:"file" ~language ())
           in
           let provider =
             DocumentFormattingEditProvider.create
               ~provideDocumentFormattingEdits:(getFormatter toolchain)
           in
           Languages.registerDocumentFormattingEditProvider ~selector ~provider)

let dispose t =
  List.iter Disposable.dispose !t;
  t := []

unit edjson_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  StdCtrls, Menus, ActnList, StdActns, ExtCtrls, fpjson;

type

  { TForm1 }

  TForm1 = class(TForm)
    ActionImport: TAction;
    ActionPrev: TAction;
    ActionNext: TAction;
    ActionList1: TActionList;
    Button2: TButton;
    Button3: TButton;
    FileExit1: TFileExit;
    FileOpen1: TFileOpen;
    FileSaveAs1: TFileSaveAs;
    Label1: TLabel;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    OpenDialogImport: TOpenDialog;
    Panel1: TPanel;
    StatusBar1: TStatusBar;
    TreeView1: TTreeView;
    procedure ActionImportExecute(Sender: TObject);
    procedure ActionNextExecute(Sender: TObject);
    procedure ActionPrevExecute(Sender: TObject);
    procedure FileOpen1Accept(Sender: TObject);
    procedure FileSaveAs1Accept(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormDestroy(Sender: TObject);
    procedure Memo1Exit(Sender: TObject);
    procedure TreeView1DblClick(Sender: TObject);
    procedure TreeView1Enter(Sender: TObject);
    procedure TreeView1KeyPress(Sender: TObject; var Key: char);
    procedure TreeView1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TreeView1SelectionChanged(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
    procedure AddJsonData(pa:TTreeNode; Data: TJSONData);
    procedure MemoDoChanges;
    procedure MemoDoEditFocus;
    procedure SaveJson(FileName:string; Data:TJSONData);
    procedure ImportJsonData(const Path:string; Data: TJSONData);
    procedure ImportJson(FileName:string);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  jsonparser;

var
  koData : TJSONData = nil;
  pnode : TTreeNode = nil;
  JsonModified : Boolean = False;
  koImport : TJSONData = nil;
  patchCount:Integer = 0;

{ TForm1 }


procedure TForm1.FileOpen1Accept(Sender: TObject);
var
  fj : TFileStream;
  ps : TJSONParser;
begin
  FreeAndNil(koData);
  pnode:=nil;
  TreeView1.Items.Clear;
  try
    fj := TFileStream.Create(pchar(FileOpen1.Dialog.FileName),fmOpenRead);
    try
      ps := TJSONParser.Create(fj);
      try
        koData:=ps.Parse;
      finally
        ps.Free;
      end;
    finally
      fj.Free;
    end;
    AddJsonData(TreeView1.Items.GetFirstNode,koData);
    StatusBar1.Panels[0].Text:=pchar(ExtractFileName(FileOpen1.Dialog.FileName));
  except
    on e:exception do ShowMessage(e.Message);
  end;
  JsonModified:=False;
end;

procedure TForm1.ActionNextExecute(Sender: TObject);
var
  n, p, q : TTreeNode;
begin
  MemoDoChanges;
  n := TreeView1.Selected;
  if n=nil then
    n:=TreeView1.Items.GetFirstNode;
  if n<>nil then begin
    while n<>nil do begin
      p:=nil;
      if n.HasChildren then
        p:=n.GetFirstChild
        else begin
          while n<>nil do begin
            p:=n.GetNextSibling;
            if p=nil then
              p:=n.Parent
              else
                break;
            n:=p;
          end;
        end;
      n:=p;
      if (n<>nil) and (TJSONData(n.Data).JSONType=jtString) then
        break;
    end;
    if n<>nil then
      n.Selected:=True;
  end;
end;

procedure TForm1.ActionImportExecute(Sender: TObject);
begin
  if OpenDialogImport.Execute then
    ImportJson(pchar(OpenDialogImport.FileName));
end;

procedure TForm1.ActionPrevExecute(Sender: TObject);
var
  n, p, q : TTreeNode;
begin
  MemoDoChanges;
  n := TreeView1.Selected;
  if n=nil then
    n:=TreeView1.Items.GetLastNode;
  if n<>nil then begin
    while n<>nil do begin
      p:=nil;
      if n.HasChildren then
        p:=n.GetLastChild
        else begin
          while n<>nil do begin
            p:=n.GetPrevSibling;
            if p=nil then
              p:=n.Parent
              else
                break;
            n:=p;
          end;
        end;
      n:=p;
      if (n<>nil) and (TJSONData(n.Data).JSONType=jtString) then
        break;
    end;
    if n<>nil then
      n.Selected:=True;
  end;
end;

procedure TForm1.FileSaveAs1Accept(Sender: TObject);
begin
  SaveJson(pchar(FileSaveAs1.Dialog.FileName),koData);
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose:=False;
  if JsonModified then begin
    if mrYes=QuestionDlg('Modified','Lost changes. Are you sure?',mtConfirmation,[mrYes,'&Yes',mrNo,'&No','IsDefault'],'') then
      CanClose:=True;
  end else
    CanClose:=True;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(koData);
end;

procedure TForm1.Memo1Exit(Sender: TObject);
begin
  MemoDoChanges;
end;

procedure TForm1.TreeView1DblClick(Sender: TObject);
begin
  MemoDoEditFocus;
end;

procedure TForm1.TreeView1Enter(Sender: TObject);
begin
  MemoDoChanges;
end;

procedure TForm1.TreeView1KeyPress(Sender: TObject; var Key: char);
begin
  if key=#13 then begin
    key:=#0;
    MemoDoEditFocus;
  end;
end;

procedure TForm1.TreeView1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MemoDoChanges;
end;


procedure TForm1.TreeView1SelectionChanged(Sender: TObject);
var
  n : TTreeNode;
  s : string;
begin
  n := TreeView1.Selected;
  if n<>nil then begin
    Memo1.Enabled:=True;
    case TJSONData(n.Data).JSONType of
    jtString: s:= pchar(TJSONString(n.Data).AsString);
    jtNumber: s:= TJSONNumber(n.Data).AsString;
    else
      begin
        s := '';
        Memo1.Enabled:=False;
      end;
    end;
    Label1.Caption:=n.GetTextPath;
    Memo1.Lines.Text:=s;
    Memo1.Modified:=False;
  end else
    Memo1.Enabled:=False;
  pnode:=n;
end;

procedure TForm1.AddJsonData(pa: TTreeNode; Data: TJSONData);
var
  N:TTreeNode;
  i : integer;
begin
  N:=nil;
  if assigned(Data) then begin
    case Data.JSONType of
    jtObject: begin
               for i:=0 to Data.Count-1 do begin
                 N:=TreeView1.Items.AddChildObject(pa,TJSONObject(Data).Names[i],TJSONObject(Data).Items[i]);
                 AddJsonData(N,TJSONObject(Data).Items[i]);
               end;
              end;
    jtArray : begin
               for i:=0 to Data.Count-1 do begin
                 N:=TreeView1.Items.AddChildObject(pa,TJSONArray(Data).Strings[i],TJSONArray(Data).Items[i]);
               end;
              end;
    jtNull:   begin
               N:=TreeView1.Items.AddChildObject(pa,'nil',Data);
              end;
    {
    jtString, jtNumber: ;
    else begin
           N:=TreeView1.Items.AddChildObject(pa,pchar(Data.AsString),Data);
         end;
    }
    end;
  end;
end;

procedure TForm1.MemoDoChanges;
begin
  if Memo1.Modified and (pnode<>nil) then begin
    case TJSONData(pnode.Data).JSONType of
    jtString: TJSONString(pnode.Data).AsUnicodeString:= UTF8Decode(
      Memo1.Lines.Text);
    jtNumber: TJSONNumber(pnode.Data).AsString:= Memo1.Lines.Text;
    end;
    JsonModified:=True;
    Memo1.Modified:=False;
  end;
end;

procedure TForm1.MemoDoEditFocus;
begin
  TreeView1SelectionChanged(nil);
  if Memo1.Enabled then
    Memo1.SetFocus;
end;

procedure TForm1.SaveJson(FileName: string; Data: TJSONData);
var
  sout:string;
  fs : TFileStream;
begin
  sout:=pchar(Data.FormatJSON());
  try
    fs := TFileStream.Create(FileName,fmOpenReadWrite or fmCreate);
    try
      fs.Write(sout[1],length(sout));
      JsonModified:=False;
      StatusBar1.Panels[0].Text:=pchar(ExtractFileName(FileName));
    finally
      fs.Free;
    end;
  except
    on e: exception do ShowMessage(e.Message);
  end;
end;

procedure TForm1.ImportJsonData(const Path: string; Data: TJSONData);
var
  i : integer;
  s : string;
  js : TJSONData;
begin
  if assigned(Data) then begin
    case Data.JSONType of
    jtObject: begin
               for i:=0 to Data.Count-1 do begin
                 s:=Path+'.'+TJSONObject(Data).Names[i];
                 ImportJsonData(s,TJSONObject(Data).Items[i]);
               end;
              end;
    jtString: if koData<>nil then begin
               js:=TJSONObject(koData).FindPath(Path);
               if js<>nil then begin
                 TJSONString(js).AsUnicodeString:=TJSONString(Data).AsUnicodeString;
                 JsonModified:=True;
                 Inc(patchCount);
               end;
              end;
    else
      ;
    end;
  end;
end;

procedure TForm1.ImportJson(FileName: string);
var
  fj : TFileStream;
  ps : TJSONParser;
begin
  FreeAndNil(koImport);
  patchCount:=0;
  try
    fj := TFileStream.Create(pchar(FileName),fmOpenRead);
    try
      ps := TJSONParser.Create(fj);
      try
        koImport:=ps.Parse;
      finally
        ps.Free;
      end;
    finally
      fj.Free;
    end;
    ImportJsonData('',koImport);
    if TreeView1.Selected<>nil then
      TreeView1SelectionChanged(nil);
    MessageDlg('Import Done',Format(' %d string value(s) imported ',[patchCount]),mtInformation,[mbOK],'');
  except
    on e:exception do ShowMessage(e.Message);
  end;
  FreeAndNil(koImport);
end;

end.


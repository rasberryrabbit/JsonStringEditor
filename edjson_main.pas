unit edjson_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  StdCtrls, Menus, ActnList, StdActns, ExtCtrls, fpjson;

type

  { TForm1 }

  TForm1 = class(TForm)
    ActionFindStringFirst: TAction;
    ActionFindString: TAction;
    ActionTranslate: TAction;
    ActionImportNode: TAction;
    ActionImport: TAction;
    ActionPrev: TAction;
    ActionNext: TAction;
    ActionList1: TActionList;
    Button2: TButton;
    Button3: TButton;
    ComboBoxtoLang: TComboBox;
    FileExit1: TFileExit;
    FileOpen1: TFileOpen;
    FileSaveAs1: TFileSaveAs;
    FindDialog1: TFindDialog;
    Label1: TLabel;
    MainMenu1: TMainMenu;
    Memo1: TMemo;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    OpenDialogImport: TOpenDialog;
    Panel1: TPanel;
    Panel2: TPanel;
    PopupMenu1: TPopupMenu;
    StatusBar1: TStatusBar;
    TreeView1: TTreeView;
    procedure ActionFindStringExecute(Sender: TObject);
    procedure ActionFindStringFirstExecute(Sender: TObject);
    procedure ActionImportExecute(Sender: TObject);
    procedure ActionImportNodeExecute(Sender: TObject);
    procedure ActionNextExecute(Sender: TObject);
    procedure ActionPrevExecute(Sender: TObject);
    procedure ActionTranslateExecute(Sender: TObject);
    procedure FileOpen1Accept(Sender: TObject);
    procedure FileSaveAs1Accept(Sender: TObject);
    procedure FindDialog1Find(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
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

    mFindStr : string;

    procedure AddJsonData(pa:TTreeNode; Data: TJSONData);
    procedure MemoDoChanges;
    procedure MemoDoEditFocus;
    procedure SaveJson(FileName:string; Data:TJSONData);
    procedure ImportJsonData(const Path:string; Data: TJSONData);
    procedure ImportJson(const FileName: string; root_path: string);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  jsonparser, windows, uGoogleTranApi, LazUTF8, RegExpr;

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
    if n<>nil then begin
      TreeView1.Selected:=n;
      TreeView1.TopItem:=n;
    end;
  end;
end;

procedure TForm1.ActionImportExecute(Sender: TObject);
begin
  if OpenDialogImport.Execute then
    ImportJson(pchar(OpenDialogImport.FileName),'');
end;

procedure TForm1.ActionFindStringExecute(Sender: TObject);
var
  n, p, q : TTreeNode;
  istr : string;
  rfind : TRegExpr;
begin
  n := TreeView1.Selected;
  if n=nil then
    n:=TreeView1.Items.GetFirstNode;
  mFindStr:=pchar(FindDialog1.FindText);
  if (n<>nil) and (mFindStr<>'') then begin
    q := n;
    rfind := TRegExpr.Create(pchar(mFindStr));
    try
      if not (frMatchCase in FindDialog1.Options) then
        rfind.ModifierI:=True;
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
        if n=nil then
          n:=TreeView1.Items.GetFirstNode;
        if q = n then
          break;
        if (n<>nil) and (TJSONData(n.Data).JSONType=jtString) then begin
          istr:=UTF8Encode(TJSONData(n.Data).AsUnicodeString);
          if rfind.Exec(pchar(istr)) then
            break;
        end;
      end;
    finally
      rfind.Free;
    end;
    if n<>nil then begin
      TreeView1.Selected:=n;
      TreeView1.TopItem:=n;
    end;
  end;
end;

procedure TForm1.ActionFindStringFirstExecute(Sender: TObject);
begin
  FindDialog1.Execute;
end;

procedure TForm1.ActionImportNodeExecute(Sender: TObject);
var
  n : TTreeNode;
  nodename : string;
begin
  n:=TreeView1.Selected;
  if n<>nil then begin
    if OpenDialogImport.Execute then begin
      nodename := '';
      // make nodename
      while n<>nil do begin
        if nodename<>'' then
          nodename := pchar(n.Text)+ '.' + nodename
          else
            nodename := pchar(n.Text);
        n:=n.Parent;
      end;
      ImportJson(pchar(OpenDialogImport.FileName),nodename);
    end;
  end;
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
    if n<>nil then begin
      TreeView1.Selected:=n;
      TreeView1.TopItem:=n;
    end;
  end;
end;

procedure TForm1.ActionTranslateExecute(Sender: TObject);
var
  soutput: string;
begin
  if not Memo1.Enabled then
    exit;
  if Memo1.SelLength>0 then begin
    soutput:=GoogleTranAPI_Translate('',ComboBoxtoLang.Text,pchar(Memo1.SelText));
    Memo1.SelText:=soutput+' / '+Memo1.SelText;
  end else begin
    soutput:=GoogleTranAPI_Translate('',ComboBoxtoLang.Text,pchar(Memo1.Text));
    Memo1.Text:=soutput+' / '+Memo1.Text;
  end;
end;

procedure TForm1.FileSaveAs1Accept(Sender: TObject);
begin
  SaveJson(pchar(FileSaveAs1.Dialog.FileName),koData);
end;

procedure TForm1.FindDialog1Find(Sender: TObject);
begin
  ActionFindStringExecute(nil);
  FindDialog1.CloseDialog;
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

procedure TForm1.FormCreate(Sender: TObject);
begin

end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  FreeAndNil(koData);
end;

procedure TForm1.FormShow(Sender: TObject);
var
  lid : string;
begin
  GoogleTranAPI_GetLangs(ComboBoxtoLang.Items);
  LazGetShortLanguageID(lid);
  ComboBoxtoLang.Text:=lid;
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
                 N:=TreeView1.Items.AddChildObject(pa,pchar(TJSONObject(Data).Names[i]),TJSONObject(Data).Items[i]);
                 AddJsonData(N,TJSONObject(Data).Items[i]);
               end;
              end;
    jtArray : begin
               for i:=0 to Data.Count-1 do begin
                 N:=TreeView1.Items.AddChildObject(pa,pchar(TJSONArray(Data).Strings[i]),TJSONArray(Data).Items[i]);
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
var
  unode:TTreeNode;
  doUpdateLabel: Boolean;
begin
  if Memo1.Modified and (pnode<>nil) then begin
    doUpdateLabel:=False;
    unode:=pnode.Parent;
    if unode<>nil then
      doUpdateLabel:=TJSONData(unode.Data).JSONType=jtArray;
    case TJSONData(pnode.Data).JSONType of
    jtString: begin
                TJSONString(pnode.Data).AsUnicodeString:= UTF8Decode(Memo1.Lines.Text);
                if doUpdateLabel then
                  pnode.Text:=pchar(Memo1.Lines.Text);
              end;
    jtNumber: begin
                TJSONNumber(pnode.Data).AsString:= Memo1.Lines.Text;
                if doUpdateLabel then
                  pnode.Text:=pchar(Memo1.Lines.Text);
              end;
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

procedure TForm1.ImportJson(const FileName: string; root_path:string);
var
  fj : TFileStream;
  ps : TJSONParser;
  start_data:TJSONData;
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
    if root_path<>'' then
      start_data:=koImport.FindPath(root_path)
      else
        start_data:=koImport;
    if start_data<>nil then
      ImportJsonData(root_path,start_data);
    if TreeView1.Selected<>nil then
      TreeView1SelectionChanged(nil);
    MessageDlg('Import Done',Format(' %d string value(s) imported ',[patchCount]),mtInformation,[mbOK],'');
  except
    on e:exception do ShowMessage(e.Message);
  end;
  FreeAndNil(koImport);
end;

end.


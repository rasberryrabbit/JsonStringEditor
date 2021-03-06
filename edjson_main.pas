unit edjson_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ComCtrls,
  StdCtrls, Menus, ActnList, StdActns, ExtCtrls, fpjson;

type

  { TFormMain }

  TFormMain = class(TForm)
    FileSaveC: TAction;
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
    MenuItem16: TMenuItem;
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
    procedure FileSaveCExecute(Sender: TObject);
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
    IsOpened : Boolean;

    procedure AddJsonData(pa:TTreeNode; Data: TJSONData);
    procedure MemoDoChanges;
    procedure MemoDoEditFocus;
    procedure SaveJson(FileName:string; Data:TJSONData);
    procedure ImportJsonData(const Path:string; Data: TJSONData);
    procedure ImportJson(const FileName: string; root_path: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

uses
  jsonparser, windows, uGoogleTranApi, LazUTF8, RegExpr, LazUTF8Classes,
  DefaultTranslator, PasJSON;

var
  koData : TJSONData = nil;
  pnode : TTreeNode = nil;
  JsonModified : Boolean = False;
  koImport : TJSONData = nil;
  patchCount:Integer = 0;
  dups : Integer = 0;

const
  utf8_bom : array[0..2] of byte = ($ef, $bb, $bf);

resourcestring
  rsImportDoneMsg = ' %d string value(s) imported ';
  rsLostChangesA = 'Lost changes. Are you sure?';
  rsImportDoneDlg = 'Import Done';
  rsModifiedDlg = 'Modified';
  rsYes = '&Yes';
  rsNo = '&No';


{ TFormMain }


function FixJson(const s:string):string;
begin
  // fix item separator comma
  Result:=ReplaceRegExpr(',(\s+?})',s,'$1',True);
  Result:=ReplaceRegExpr('([^\\])"(\s+)"',Result,'$1",$2"',True);
end;


procedure RemoveDups(tx:TPasJSONItemObject);
var
  i, j: Integer;
begin
  for i:=0 to tx.Count-1 do begin
    if i+1<tx.Count then
    for j:=i+1 to tx.Count-1 do begin
      if tx.Keys[i]=tx.Keys[j] then begin
        tx.Delete(i);
        Inc(dups);
        break;
      end;
    end;
    if (i<tx.Count) and (tx.Values[i] is TPasJSONItemObject) then
      RemoveDups(TPasJSONItemObject(tx.Values[i]));
  end;
end;

procedure TFormMain.FileOpen1Accept(Sender: TObject);
const
  utf8_bom : array[0..2] of byte = ($ef, $bb, $bf);
var
  fj : TStringStream;
  dummy : array[0..3] of byte;
  s : string;
  tx:TPasJSONItemObject;
  ttx:TPasJSONItemObjectProperty;
begin
  FreeAndNil(koData);
  pnode:=nil;
  TreeView1.Items.Clear;
  TreeView1.Items.BeginUpdate;
  try
    fj := TStringStream.Create;
    try
      fj.LoadFromFile(FileOpen1.Dialog.FileName);
      if fj.Read(dummy[0],3)=3 then begin
        if not CompareMem(@utf8_bom[0],@dummy[0],3) then
          fj.Position:=0;
      end else
        fj.Position:=0;
      dups:=0;
      s:=FixJson(fj.ReadString(fj.Size));
      tx:=TPasJSONItemObject(TPasJSON.Parse(s,[TPasJSONModeFlag.Comments],TPasJSONEncoding.UTF8));
      RemoveDups(TPasJSONItemObject(tx));
      fj.Clear;
      TPasJSON.StringifyToStream(fj,tx);
      tx.Free;
      fj.Position:=0;
      koData:=GetJSON(fj);
    finally
      fj.Free;
    end;

    AddJsonData(TreeView1.Items.GetFirstNode,koData);
    IsOpened:=True;
    StatusBar1.Panels[0].Text:=pchar({ExtractFileName}(FileOpen1.Dialog.FileName));
    FileSaveAs1.Dialog.FileName:=FileOpen1.Dialog.FileName;
  except
    on e:exception do ShowMessage(e.Message);
  end;
  TreeView1.Items.EndUpdate;
  JsonModified:=False;
end;

procedure TFormMain.ActionNextExecute(Sender: TObject);
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
      //TreeView1.TopItem:=n;
      TreeView1.Invalidate;
    end;
  end;
end;

procedure TFormMain.ActionImportExecute(Sender: TObject);
begin
  if OpenDialogImport.Execute then
    ImportJson(pchar(OpenDialogImport.FileName),'');
end;

procedure TFormMain.ActionFindStringExecute(Sender: TObject);
var
  n, p, q : TTreeNode;
  istr, mFindStr : string;
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
      //TreeView1.TopItem:=n;
      TreeView1.Invalidate;
    end;
  end;
end;

procedure TFormMain.ActionFindStringFirstExecute(Sender: TObject);
begin
  FindDialog1.Execute;
end;

procedure TFormMain.ActionImportNodeExecute(Sender: TObject);
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

procedure TFormMain.ActionPrevExecute(Sender: TObject);
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
      //TreeView1.TopItem:=n;
      TreeView1.Invalidate;
    end;
  end;
end;

procedure TFormMain.ActionTranslateExecute(Sender: TObject);
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

procedure TFormMain.FileSaveAs1Accept(Sender: TObject);
begin
  if Sender=nil then
    FileSaveAs1.Dialog.FileName:=FileOpen1.Dialog.FileName;
  SaveJson(pchar(FileSaveAs1.Dialog.FileName),koData);
  FileOpen1.Dialog.FileName:=FileSaveAs1.Dialog.FileName;
end;

procedure TFormMain.FileSaveCExecute(Sender: TObject);
begin
  {if IsOpened then
    FileSaveAs1Accept(nil)
    else}
      FileSaveAs1.Execute;
end;

procedure TFormMain.FindDialog1Find(Sender: TObject);
begin
  ActionFindStringExecute(nil);
  FindDialog1.CloseDialog;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  CanClose:=False;
  if JsonModified then begin
    if mrYes=QuestionDlg(rsModifiedDlg, rsLostChangesA, mtConfirmation, [mrYes,
      rsYes, mrNo, rsNo, 'IsDefault'], '') then
      CanClose:=True;
  end else
    CanClose:=True;
end;

procedure TFormMain.FormCreate(Sender: TObject);
begin
  IsOpened:=False;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FreeAndNil(koData);
end;

procedure TFormMain.FormShow(Sender: TObject);
var
  lid : string;
begin
  GoogleTranAPI_GetLangs(ComboBoxtoLang.Items);
  LazGetShortLanguageID(lid);
  ComboBoxtoLang.Text:=lid;
  if ParamCount>1 then begin
    FileOpen1.Dialog.FileName:=ParamStrUTF8(1);
    FileOpen1Accept(nil);
  end;
end;

procedure TFormMain.Memo1Exit(Sender: TObject);
begin
  MemoDoChanges;
end;

procedure TFormMain.TreeView1DblClick(Sender: TObject);
begin
  MemoDoEditFocus;
end;

procedure TFormMain.TreeView1Enter(Sender: TObject);
begin
  MemoDoChanges;
end;

procedure TFormMain.TreeView1KeyPress(Sender: TObject; var Key: char);
begin
  if key=#13 then begin
    key:=#0;
    MemoDoEditFocus;
  end;
end;

procedure TFormMain.TreeView1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  MemoDoChanges;
end;


procedure TFormMain.TreeView1SelectionChanged(Sender: TObject);
var
  n : TTreeNode;
  s : string;
begin
  n := TreeView1.Selected;
  if n<>nil then begin
    Memo1.Enabled:=True;
    case TJSONData(n.Data).JSONType of
    jtString: s:= pchar(UTF8Encode(TJSONString(n.Data).AsUnicodeString));
    jtNumber: s:= TJSONNumber(n.Data).AsString;
    else
      begin
        s := '';
        Memo1.Enabled:=False;
      end;
    end;
    Label1.Caption:=n.GetTextPath;
    Memo1.Lines.Text:=pchar(s);
    Memo1.Modified:=False;
  end else
    Memo1.Enabled:=False;
  pnode:=n;
end;

procedure TFormMain.AddJsonData(pa: TTreeNode; Data: TJSONData);
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
               for i:=0 to Data.Count-1 do
                 N:=TreeView1.Items.AddChildObject(pa,pchar(UTF8Encode(TJSONArray(Data).UnicodeStrings[i])),TJSONArray(Data).Items[i]);
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

procedure TFormMain.MemoDoChanges;
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

procedure TFormMain.MemoDoEditFocus;
begin
  TreeView1SelectionChanged(nil);
  if Memo1.Enabled then
    Memo1.SetFocus;
end;

procedure TFormMain.SaveJson(FileName: string; Data: TJSONData);
var
  sout:string;
  fs : TFileStreamUTF8;
begin
  sout:=pchar(Data.FormatJSON());
  try
    fs := TFileStreamUTF8.Create(FileName,fmOpenReadWrite or fmCreate);
    try
      fs.Write(sout[1],length(sout));
      JsonModified:=False;
      StatusBar1.Panels[0].Text:=pchar({ExtractFileName}(FileName));
    finally
      fs.Free;
    end;
  except
    on e: exception do ShowMessage(e.Message);
  end;
end;

procedure TFormMain.ImportJsonData(const Path: string; Data: TJSONData);
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

procedure TFormMain.ImportJson(const FileName: string; root_path:string);
var
  fj : TStringStream;
  start_data:TJSONData;
  dummy : array[0..3] of byte;
  s: string;
  tx: TPasJSONItemObject;
begin
  FreeAndNil(koImport);
  patchCount:=0;
  try
    fj := TStringStream.Create;
    try
      fj.LoadFromFile(FileName);
      if fj.Read(dummy,3)=3 then begin
        if not CompareMem(@dummy[0],@utf8_bom[0],3) then
          fj.Position:=0;
      end else
        fj.Position:=0;

      dups:=0;
      s:=FixJson(fj.ReadString(fj.Size));
      tx:=TPasJSONItemObject(TPasJSON.Parse(s,[TPasJSONModeFlag.Comments],TPasJSONEncoding.UTF8));
      RemoveDups(TPasJSONItemObject(tx));
      fj.Clear;
      TPasJSON.StringifyToStream(fj,tx);
      tx.Free;
      fj.Position:=0;

      koImport:=GetJSON(fj);
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
    MessageDlg(rsImportDoneDlg, Format(rsImportDoneMsg, [patchCount]),
      mtInformation, [mbOK], '');
  except
    on e:exception do ShowMessage(e.Message);
  end;
  FreeAndNil(koImport);
end;

end.


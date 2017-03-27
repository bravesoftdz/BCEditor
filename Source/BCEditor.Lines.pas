unit BCEditor.Lines;

interface {********************************************************************}

uses
  SysUtils, Classes,
  Graphics, Controls,
  BCEditor.Utils, BCEditor.Consts, BCEditor.Types;

type
  TBCEditorLines = class(TStrings)
  protected type
    TChangeEvent = procedure(Sender: TObject; const Line: Integer) of object;
    TCompare = function(Lines: TBCEditorLines; Line1, Line2: Integer): Integer;

    TLineState = (lsLoaded, lsModified, lsSaved);

    TOption = (loColumns, loTrimTrailingLines, loTrimTrailingSpaces, loUndoGrouped, loUndoAfterLoad, loUndoAfterSave);
    TOptions = set of TOption;

    TRange = Pointer;

    PLineAttribute = ^TLineAttribute;
    TLineAttribute = packed record
      Background: TColor;
      Foreground: TColor;
      LineState: TLineState;
    end;

    TLine = packed record
      Attribute: TLineAttribute;
      ExpandedLength: Integer;
      Flags: set of (sfHasTabs, sfHasNoTabs);
      Range: TRange;
      FirstRow: Integer;
      Text: string;
    end;
    TLines = array of TLine;

    TState = set of (lsLoading, lsDontTrim, lsUndo, lsRedo, lsCaretMoved, lsSelChanged, lsTextChanged);

    TUndoList = class(TPersistent)
    type
      TUndoType = (utSelection, utInsert, utReplace, utBackspace, utDelete,
        utClear, utInsertIndent, utDeleteIndent);

      PItem = ^TItem;
      TItem = packed record
        BlockNumber: Integer;
        UndoType: TUndoType;
        CaretPosition: TBCEditorTextPosition;
        SelBeginPosition: TBCEditorTextPosition;
        SelEndPosition: TBCEditorTextPosition;
        SelMode: TBCEditorSelectionMode;
        BeginPosition: TBCEditorTextPosition;
        EndPosition: TBCEditorTextPosition;
        Text: string;
      end;

    strict private
      FBlockNumber: Integer;
      FChanges: Integer;
      FCount: Integer;
      FCurrentBlockNumber: Integer;
      FGroupBreak: Boolean;
      FItems: array of TItem;
      FLines: TBCEditorLines;
      FUpdateCount: Integer;
      function GetItemCount(): Integer; inline;
      function GetItems(const AIndex: Integer): TItem;
      function GetUpdated(): Boolean;
      procedure Grow();
      procedure SetItems(const AIndex: Integer; const AValue: TItem);
    protected
      procedure BeginUpdate();
      procedure Clear();
      constructor Create(const ALines: TBCEditorLines);
      procedure EndUpdate();
      procedure GroupBreak();
      function PeekItem(out Item: PItem): Boolean;
      function PopItem(out Item: PItem): Boolean;
      procedure PushItem(const AUndoType: TUndoType; const ACaretPosition: TBCEditorTextPosition;
        const ASelBeginPosition, ASelEndPosition: TBCEditorTextPosition; const ASelMode: TBCEditorSelectionMode;
        const ABeginPosition, AEndPosition: TBCEditorTextPosition; const AText: string = '';
        const ABlockNumber: Integer = 0); overload;
      property Count: Integer read FCount;
      property Changes: Integer read FChanges;
      property ItemCount: Integer read GetItemCount;
      property Items[const AIndex: Integer]: TItem read GetItems write SetItems;
      property Lines: TBCEditorLines read FLines;
      property Updated: Boolean read GetUpdated;
    public
      procedure Assign(ASource: TPersistent); override;
      property UpdateCount: Integer read FUpdateCount;
    end;

  const
    BOFPosition: TBCEditorTextPosition = (Char: 0; Line: 0);
    InvalidPosition: TBCEditorTextPosition = (Char: -1; Line: -1);
  strict private const
    DefaultOptions = [loUndoGrouped];
  strict private
    FCapacity: Integer;
    FCaretPosition: TBCEditorTextPosition;
    FCaseSensitive: Boolean;
    FCount: Integer;
    FEditor: TCustomControl;
    FLines: TLines;
    FMaxLengthLine: Integer;
    FModified: Boolean;
    FOldCaretPosition: TBCEditorTextPosition;
    FOldSelBeginPosition: TBCEditorTextPosition;
    FOldSelEndPosition: TBCEditorTextPosition;
    FOldUndoListCount: Integer;
    FOnAfterLoad: TNotifyEvent;
    FOnBeforeLoad: TNotifyEvent;
    FOnCaretMoved: TNotifyEvent;
    FOnCleared: TNotifyEvent;
    FOnDeleted: TChangeEvent;
    FOnInserted: TChangeEvent;
    FOnSelChange: TNotifyEvent;
    FOnUpdated: TChangeEvent;
    FOptions: TOptions;
    FReadOnly: Boolean;
    FRedoList: TUndoList;
    FSelBeginPosition: TBCEditorTextPosition;
    FSelEndPosition: TBCEditorTextPosition;
    FSelMode: TBCEditorSelectionMode;
    FSortOrder: TBCEditorSortOrder;
    FState: TState;
    FTabWidth: Integer;
    FUndoList: TUndoList;
    function CalcExpandString(ALine: Integer): string;
    procedure DoDelete(ALine: Integer);
    procedure DoDeleteIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
    procedure DoDeleteText(ABeginPosition, AEndPosition: TBCEditorTextPosition);
    procedure DoInsertIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
    procedure DoInsert(ALine: Integer; const AText: string);
    function DoInsertText(APosition: TBCEditorTextPosition;
      const AText: string): TBCEditorTextPosition;
    procedure DoPut(ALine: Integer; const AText: string);
    procedure ExchangeItems(ALine1, ALine2: Integer);
    procedure ExecuteUndoRedo(const List: TUndoList);
    function GetAttributes(ALine: Integer): PLineAttribute;
    function GetBOLPosition(ALine: Integer): TBCEditorTextPosition; inline;
    function GetCanRedo(): Boolean;
    function GetCanUndo(): Boolean;
    function GetEOFPosition(): TBCEditorTextPosition;
    function GetEOLPosition(ALine: Integer): TBCEditorTextPosition;
    function GetExpandedString(ALine: Integer): string;
    function GetExpandedStringLength(ALine: Integer): Integer;
    function GetMaxLength(): Integer;
    function GetFirstRow(ALine: Integer): Integer; inline;
    function GetRange(ALine: Integer): TRange;
    function GetTextBetween(const ABeginPosition, AEndPosition: TBCEditorTextPosition): string; overload;
    function GetTextBetweenColumn(const ABeginPosition, AEndPosition: TBCEditorTextPosition): string; overload;
    procedure Grow();
    procedure InternalClear(const AClearUndo: Boolean); overload;
    procedure PutAttributes(ALine: Integer; const AValue: PLineAttribute);
    procedure PutRange(ALine: Integer; ARange: TRange); inline;
    procedure PutFirstRow(ALine: Integer; const ARow: Integer); inline;
    procedure SetCaretPosition(const AValue: TBCEditorTextPosition);
    procedure SetModified(const AValue: Boolean);
    procedure SetOptions(const AValue: TOptions);
    procedure SetSelBeginPosition(const AValue: TBCEditorTextPosition);
    procedure SetSelEndPosition(const AValue: TBCEditorTextPosition);
    procedure QuickSort(ALeft, ARight: Integer; ACompare: TCompare);
    property Capacity: Integer read FCapacity write SetCapacity;
  protected
    procedure Backspace(ABeginPosition, AEndPosition: TBCEditorTextPosition);
    procedure ClearUndo();
    function CharIndexToPosition(const ACharIndex: Integer): TBCEditorTextPosition; overload; inline;
    function CharIndexToPosition(const ACharIndex: Integer;
      const ARelativePosition: TBCEditorTextPosition): TBCEditorTextPosition; overload;
    function CompareStrings(const S1, S2: string): Integer; override;
    procedure CustomSort(const ABeginLine, AEndLine: Integer; ACompare: TCompare);
    procedure DeleteIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
    procedure DeleteText(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const ASelMode: TBCEditorSelectionMode = smNormal); overload;
    function Get(ALine: Integer): string; override;
    function GetCapacity: Integer; override;
    function GetCount: Integer; override;
    function GetTextLength(): Integer;
    function GetTextStr(): string; override;
    procedure InsertIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
    procedure InsertText(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const AText: string); overload;
    function InsertText(APosition: TBCEditorTextPosition;
      const AText: string): TBCEditorTextPosition; overload;
    function IsPositionInSelection(const APosition: TBCEditorTextPosition): Boolean;
    function PositionToCharIndex(const APosition: TBCEditorTextPosition): Integer;
    procedure Put(ALine: Integer; const AText: string); override;
    procedure Redo(); inline;
    function ReplaceText(ABeginPosition, AEndPosition: TBCEditorTextPosition;
      const AText: string): TBCEditorTextPosition;
    procedure SetCapacity(AValue: Integer); override;
    procedure SetTabWidth(const AValue: Integer);
    procedure SetTextStr(const AValue: string); override;
    procedure SetUpdateState(AUpdating: Boolean); override;
    procedure Sort(const ABeginLine, AEndLine: Integer); virtual;
    procedure Undo(); inline;
    procedure UndoGroupBreak();
    property Attributes[ALine: Integer]: PLineAttribute read GetAttributes write PutAttributes;
    property BOLPosition[ALine: Integer]: TBCEditorTextPosition read GetBOLPosition;
    property CanRedo: Boolean read GetCanRedo;
    property CanUndo: Boolean read GetCanUndo;
    property CaretPosition: TBCEditorTextPosition read FCaretPosition write SetCaretPosition;
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive default False;
    property Editor: TCustomControl read FEditor write FEditor;
    property EOFPosition: TBCEditorTextPosition read GetEOFPosition;
    property EOLPosition[ALine: Integer]: TBCEditorTextPosition read GetEOLPosition;
    property ExpandedStringLengths[ALine: Integer]: Integer read GetExpandedStringLength;
    property ExpandedStrings[Line: Integer]: string read GetExpandedString;
    property FirstRow[Line: Integer]: Integer read GetFirstRow write PutFirstRow;
    property Lines: TLines read FLines;
    property MaxLength: Integer read GetMaxLength;
    property Modified: Boolean read FModified write SetModified;
    property OnAfterLoad: TNotifyEvent read FOnAfterLoad write FOnAfterLoad;
    property OnBeforeLoad: TNotifyEvent read FOnBeforeLoad write FOnBeforeLoad;
    property OnCaretMoved: TNotifyEvent read FOnCaretMoved write FOnCaretMoved;
    property OnCleared: TNotifyEvent read FOnCleared write FOnCleared;
    property OnDeleted: TChangeEvent read FOnDeleted write FOnDeleted;
    property OnInserted: TChangeEvent read FOnInserted write FOnInserted;
    property OnSelChange: TNotifyEvent read FOnSelChange write FOnSelChange;
    property OnUpdated: TChangeEvent read FOnUpdated write FOnUpdated;
    property Options: TOptions read FOptions write SetOptions;
    property Ranges[Line: Integer]: TRange read GetRange write PutRange;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property RedoList: TUndoList read FRedoList;
    property SelBeginPosition: TBCEditorTextPosition read FSelBeginPosition write SetSelBeginPosition;
    property SelEndPosition: TBCEditorTextPosition read FSelEndPosition write SetSelEndPosition;
    property SelMode: TBCEditorSelectionMode read FSelMode write FSelMode;
    property SortOrder: TBCEditorSortOrder read FSortOrder write FSortOrder;
    property State: TState read FState;
    property TabWidth: Integer read FTabWidth write SetTabWidth;
    property TextBetween[const BeginPosition, EndPosition: TBCEditorTextPosition]: string read GetTextBetween;
    property TextBetweenColumn[const BeginPosition, EndPosition: TBCEditorTextPosition]: string read GetTextBetweenColumn;
    property UndoList: TUndoList read FUndoList;
  public
    function Add(const AText: string): Integer; override;
    procedure Clear(); overload; override;
    constructor Create(const AEditor: TCustomControl);
    procedure Delete(ALine: Integer); overload; override;
    destructor Destroy; override;
    procedure Insert(ALine: Integer; const AText: string); override;
    procedure SaveToStream(AStream: TStream; AEncoding: TEncoding = nil); override;
  end;

implementation {***************************************************************}

uses
  Math, StrUtils, SysConst;

resourcestring
  SCharIndexInLineBreak = 'Character index is inside line break';
  SCharIndexIsNegative = 'Character index is negative';

function HasLineBreak(const Text: string): Boolean;
var
  LEndPos: PChar;
  LPos: PChar;
begin
  LPos := PChar(Text); LEndPos := PChar(@Text[Length(Text)]);
  while (LPos <= LEndPos) do
    if (CharInSet(LPos^, [BCEDITOR_LINEFEED, BCEDITOR_CARRIAGE_RETURN])) then
      Exit(True)
    else
      Inc(LPos);
  Result := False;
end;

{ TBCEditorLines.TUndoList ****************************************************}

procedure TBCEditorLines.TUndoList.Assign(ASource: TPersistent);
var
  I: Integer;
begin
  Assert(Assigned(ASource) and (ASource is TBCEditorLines.TUndoList));

  Clear();
  SetLength(FItems, TUndoList(ASource).Count);
  for I := 0 to TUndoList(ASource).Count - 1 do
    FItems[I] := TUndoList(ASource).Items[I];
  FCurrentBlockNumber := TUndoList(ASource).FCurrentBlockNumber;
end;

procedure TBCEditorLines.TUndoList.BeginUpdate();
begin
  if (UpdateCount = 0) then
  begin
    Inc(FBlockNumber);
    FChanges := 0;
    FCurrentBlockNumber := FBlockNumber;
  end;

  Inc(FUpdateCount);
end;

procedure TBCEditorLines.TUndoList.Clear();
begin
  FBlockNumber := 0;
  FCount := 0;
  FGroupBreak := False;
  SetLength(FItems, 0);
end;

constructor TBCEditorLines.TUndoList.Create(const ALines: TBCEditorLines);
begin
  inherited Create();

  FLines := ALines;

  FBlockNumber := 0;
  FCount := 0;
  FUpdateCount := 0;
end;

procedure TBCEditorLines.TUndoList.EndUpdate();
begin
  if (FUpdateCount > 0) then
  begin
    Dec(FUpdateCount);

    if (FUpdateCount = 0) then
    begin
      FChanges := 0;
      FCurrentBlockNumber := 0;
    end;
  end;
end;

function TBCEditorLines.TUndoList.GetItemCount(): Integer;
begin
  Result := FCount;
end;

function TBCEditorLines.TUndoList.GetItems(const AIndex: Integer): TItem;
begin
  Result := TItem(FItems[AIndex]);
end;

function TBCEditorLines.TUndoList.GetUpdated(): Boolean;
begin
  Result := (FUpdateCount > 0) and (FChanges > 0);
end;

procedure TBCEditorLines.TUndoList.GroupBreak();
begin
  FGroupBreak := True;
end;

procedure TBCEditorLines.TUndoList.Grow();
begin
  if (Length(FItems) > 64) then
    SetLength(FItems, Length(FItems) + Length(FItems) div 4)
  else
    SetLength(FItems, Length(FItems) + 16);
end;

function TBCEditorLines.TUndoList.PeekItem(out Item: PItem): Boolean;
begin
  Result := FCount > 0;
  if (Result) then
    Item := @FItems[FCount - 1];
end;

function TBCEditorLines.TUndoList.PopItem(out Item: PItem): Boolean;
begin
  Result := FCount > 0;
  if (Result) then
  begin
    Item := @FItems[FCount - 1];
    Dec(FCount);
  end;
end;

procedure TBCEditorLines.TUndoList.PushItem(const AUndoType: TUndoType; const ACaretPosition: TBCEditorTextPosition;
  const ASelBeginPosition, ASelEndPosition: TBCEditorTextPosition; const ASelMode: TBCEditorSelectionMode;
  const ABeginPosition, AEndPosition: TBCEditorTextPosition; const AText: string = '';
  const ABlockNumber: Integer = 0);
var
  LHandled: Boolean;
begin
  if (not (lsLoading in Lines.State)) then
  begin
    LHandled := False;
    if ((Lines.State * [lsUndo, lsRedo] = [])
      and (loUndoGrouped in Lines.Options)
      and not FGroupBreak
      and (Count > 0) and (FItems[Count - 1].UndoType = AUndoType)) then
      case (AUndoType) of
        utSelection: LHandled := True; // Ignore
        utInsert:
          if (FItems[Count - 1].EndPosition = ABeginPosition) then
          begin
            FItems[Count - 1].EndPosition := AEndPosition;
            LHandled := True;
          end;
        utReplace:
          if (FItems[Count - 1].EndPosition = ABeginPosition) then
          begin
            FItems[Count - 1].EndPosition := AEndPosition;
            FItems[Count - 1].Text := FItems[Count - 1].Text + AText;
            LHandled := True;
          end;
        utBackspace:
          if (FItems[Count - 1].BeginPosition = AEndPosition) then
          begin
            FItems[Count - 1].BeginPosition := ABeginPosition;
            FItems[Count - 1].Text := AText + FItems[Count - 1].Text;
            LHandled := True;
          end;
        utDelete:
          if (FItems[Count - 1].EndPosition = ABeginPosition) then
          begin
            FItems[Count - 1].EndPosition := AEndPosition;
            FItems[Count - 1].Text := FItems[Count - 1].Text + AText;
            LHandled := True;
          end;
      end;

    if (not LHandled) then
    begin
      if (Count = Length(FItems)) then
        Grow();

      with FItems[FCount] do
      begin
        if (ABlockNumber > 0) then
          BlockNumber := ABlockNumber
        else if (FCurrentBlockNumber > 0) then
          BlockNumber := FCurrentBlockNumber
        else
        begin
          Inc(FBlockNumber);
          BlockNumber := FBlockNumber;
        end;
        BeginPosition := ABeginPosition;
        CaretPosition := ACaretPosition;
        EndPosition := AEndPosition;
        SelBeginPosition := ASelBeginPosition;
        SelEndPosition := ASelEndPosition;
        SelMode := ASelMode;
        Text := AText;
        UndoType := AUndoType;
      end;
      Inc(FCount);
    end;

    if (UpdateCount > 0) then
      Inc(FChanges);
    FGroupBreak := False;
  end;
end;

procedure TBCEditorLines.TUndoList.SetItems(const AIndex: Integer; const AValue: TItem);
begin
  FItems[AIndex] := AValue;
end;

{ TBCEditorLines **************************************************************}

function CompareLines(ALines: TBCEditorLines; AIndex1, AIndex2: Integer): Integer;
begin
  Result := ALines.CompareStrings(ALines.Lines[AIndex1].Text, ALines.Lines[AIndex2].Text);
  if (ALines.SortOrder = soDesc) then
    Result := - Result;
end;

function TBCEditorLines.Add(const AText: string): Integer;
begin
  Result := FCount;
  Insert(Result, AText);
end;

procedure TBCEditorLines.Backspace(ABeginPosition, AEndPosition: TBCEditorTextPosition);
var
  LBeginPosition: TBCEditorTextPosition;
  LCaretPosition: TBCEditorTextPosition;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
  LText: string;
begin
  Assert((BOFPosition <= ABeginPosition) and (ABeginPosition < AEndPosition) and (AEndPosition <= EOFPosition));

  LCaretPosition := CaretPosition;
  LSelBeginPosition := SelBeginPosition;
  LSelEndPosition := SelEndPosition;

  LBeginPosition := ABeginPosition;

  if ((loTrimTrailingLines in Options)
    and (AEndPosition = EOFPosition)) then
    while ((LBeginPosition.Char = 0) and (LBeginPosition.Line > 0)) do
      LBeginPosition := EOLPosition[LBeginPosition.Line - 1];

  LText := GetTextBetween(ABeginPosition, AEndPosition);

  UndoList.BeginUpdate();
  try
    DoDeleteText(ABeginPosition, AEndPosition);

    UndoList.PushItem(utBackspace, LCaretPosition,
      LSelBeginPosition, LSelEndPosition, SelMode,
      ABeginPosition, AEndPosition, LText);
  finally
    UndoList.EndUpdate();
  end;

  CaretPosition := ABeginPosition;
end;

function TBCEditorLines.CalcExpandString(ALine: Integer): string;
var
  LHasTabs: Boolean;
begin
  with Lines[ALine] do
    if (Text = '') then
      Result := ''
    else
    begin
      Result := ConvertTabs(Text, FTabWidth, LHasTabs, loColumns in Options);

      if LHasTabs then
      begin
        Include(Flags, sfHasTabs);
        Exclude(Flags, sfHasNoTabs);
      end
      else
      begin
        Exclude(Flags, sfHasTabs);
        Include(Flags, sfHasNoTabs);
      end;
      ExpandedLength := Length(Result);
    end;
end;

function TBCEditorLines.CharIndexToPosition(const ACharIndex: Integer): TBCEditorTextPosition;
begin
  Result := CharIndexToPosition(ACharIndex, BOFPosition);
end;

function TBCEditorLines.CharIndexToPosition(const ACharIndex: Integer;
  const ARelativePosition: TBCEditorTextPosition): TBCEditorTextPosition;
var
  LLength: Integer;
  LLineBreakLength: Integer;
begin
  Assert((BOFPosition <= ARelativePosition) and (ARelativePosition <= EOFPosition) or (ACharIndex = 0) and (Count = 0));

  LLength := ACharIndex;

  if (LLength < 0) then
    raise ERangeError.Create(SCharIndexIsNegative);

  Result := ARelativePosition;

  if (LLength <= Length(Lines[Result.Line].Text) - Result.Char) then
    Inc(Result.Char, LLength)
  else
  begin
    LLineBreakLength := Length(LineBreak);

    Dec(LLength, (Length(Lines[Result.Line].Text) - Result.Char) + LLineBreakLength);
    Inc(Result.Line);

    if (LLength < 0) then
      raise ERangeError.Create(SCharIndexInLineBreak);

    while ((Result.Line < Count) and (LLength >= Length(Lines[Result.Line].Text) + LLineBreakLength)) do
    begin
      Dec(LLength, Length(Lines[Result.Line].Text) + LLineBreakLength);
      Inc(Result.Line);
    end;

    if (LLength > Length(Lines[Result.Line].Text)) then
      raise ERangeError.CreateFmt(SCharIndexOutOfBounds + ' (%d, %d / %d, %d / %d)', [ACharIndex, Length(Text), LLength, Length(Lines[Result.Line].Text), Result.Line, Count]);

    Result.Char := LLength;
  end;

  Assert(Result <= EOFPosition, 'ACharIndex: ' + IntToStr(ACharIndex) + ', RelPos: ' + ARelativePosition.ToString() + ', Result: ' + Result.ToString());
end;

procedure TBCEditorLines.Clear();
begin
  InternalClear(True);
end;

procedure TBCEditorLines.ClearUndo();
begin
  UndoList.Clear();
  RedoList.Clear();
end;

function TBCEditorLines.CompareStrings(const S1, S2: string): Integer;
begin
  if CaseSensitive then
    Result := CompareStr(S1, S2)
  else
    Result := CompareText(S1, S2);

  if SortOrder = soDesc then
    Result := -1 * Result;
end;

constructor TBCEditorLines.Create(const AEditor: TCustomControl);
begin
  inherited Create();

  FEditor := AEditor;

  FCaretPosition := BOFPosition;
  FCaseSensitive := False;
  FCount := 0;
  FMaxLengthLine := -1;
  FModified := False;
  FOnAfterLoad := nil;
  FOnBeforeLoad := nil;
  FOnCaretMoved := nil;
  FOnCleared := nil;
  FOnDeleted := nil;
  FOnInserted := nil;
  FOnSelChange := nil;
  FOnUpdated := nil;
  FOptions := DefaultOptions;
  FRedoList := TUndoList.Create(Self);
  FReadOnly := False;
  FSelBeginPosition := BOFPosition;
  FSelEndPosition := BOFPosition;
  FSelMode := smNormal;
  FState := [];
  FUndoList := TUndoList.Create(Self);
  TabWidth := 4;
end;

procedure TBCEditorLines.CustomSort(const ABeginLine, AEndLine: Integer;
  ACompare: TCompare);
var
  LBeginPosition: TBCEditorTextPosition;
  LEndPosition: TBCEditorTextPosition;
  LText: string;
begin
  BeginUpdate();
  UndoList.BeginUpdate();

  try
    LBeginPosition := BOLPosition[ABeginLine];
    if (AEndLine < Count - 1) then
      LEndPosition := BOLPosition[ABeginLine + 1]
    else
      LEndPosition := TextPosition(Length(Lines[AEndLine].Text), AEndLine);

    LText := GetTextBetween(LBeginPosition, LEndPosition);
    UndoList.PushItem(utDelete, CaretPosition,
      SelBeginPosition, SelEndPosition, SelMode,
      LBeginPosition, InvalidPosition, LText);

    QuickSort(ABeginLine, AEndLine, ACompare);

    UndoList.PushItem(utInsert, InvalidPosition,
      InvalidPosition, InvalidPosition, smNormal,
      LBeginPosition, LEndPosition);
  finally
    UndoList.EndUpdate();
    EndUpdate();
    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.Delete(ALine: Integer);
var
  LBeginPosition: TBCEditorTextPosition;
  LCaretPosition: TBCEditorTextPosition;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
  LText: string;
  LUndoType: TUndoList.TUndoType;
begin
  Assert((0 <= ALine) and (ALine < Count));

  LCaretPosition := CaretPosition;
  LSelBeginPosition := SelBeginPosition;
  LSelEndPosition := SelEndPosition;
  if (Count = 1) then
  begin
    LBeginPosition := BOFPosition;
    LText := Get(ALine);
    LUndoType := utClear;
  end
  else if (ALine < Count - 1) then
  begin
    LBeginPosition := BOLPosition[ALine];
    LText := Get(ALine) + LineBreak;
    LUndoType := utDelete;
  end
  else
  begin
    LBeginPosition := EOLPosition[ALine - 1];
    LText := LineBreak + Get(ALine);
    LUndoType := utDelete;
  end;

  UndoList.BeginUpdate();
  try
    DoDelete(ALine);

    if ((ALine = Count - 1) and (loTrimTrailingLines in Options)) then
      while ((Count > 0) and (Lines[Count - 1].Text = '')) do
        if (Count = 1) then
        begin
          LBeginPosition := BOFPosition;
          LText := Lines[Count - 1].Text + LText;
          LUndoType := utClear;
        end
        else
        begin
          LBeginPosition := EOLPosition[Count - 2];
          LText := LineBreak + Lines[Count - 1].Text + LText;
        end;

    UndoList.PushItem(LUndoType, LCaretPosition,
      LSelBeginPosition, LSelEndPosition, SelMode,
      LBeginPosition, InvalidPosition, LText);
  finally
    UndoList.EndUpdate();
  end;
end;

procedure TBCEditorLines.DeleteIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
var
  LBeginPosition: TBCEditorTextPosition;
  LCaretPosition: TBCEditorTextPosition;
  LEndPosition: TBCEditorTextPosition;
  LLine: Integer;
  LIndentFound: Boolean;
  LIndentTextLength: Integer;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
begin
  LBeginPosition := Min(ABeginPosition, AEndPosition);
  LEndPosition := Max(ABeginPosition, AEndPosition);

  Assert((BOFPosition <= LBeginPosition) and (LBeginPosition <= LEndPosition) and (LEndPosition <= EOFPosition));

  LIndentTextLength := Length(AIndentText);
  LIndentFound := LBeginPosition.Line <> LEndPosition.Line;
  for LLine := LBeginPosition.Line to LEndPosition.Line do
    if (Copy(Lines[LLine].Text, 1 + LBeginPosition.Char, LIndentTextLength) <> AIndentText) then
    begin
      LIndentFound := False;
      break;
    end;

  if (LIndentFound) then
  begin
    LCaretPosition := CaretPosition;
    LSelBeginPosition := SelBeginPosition;
    LSelEndPosition := SelEndPosition;

    DoDeleteIndent(LBeginPosition, LEndPosition, AIndentText, ASelMode);

    UndoList.PushItem(utDeleteIndent, LCaretPosition,
      LSelBeginPosition, LSelEndPosition, SelMode,
      LBeginPosition, LEndPosition, AIndentText);

    RedoList.Clear();
  end
  else
  begin
    UndoList.BeginUpdate();

    try
      for LLine := LBeginPosition.Line to LEndPosition.Line do
        if (LeftStr(Lines[LLine].Text, LIndentTextLength) = AIndentText) then
          DeleteText(BOLPosition[LLine], TextPosition(Length(AIndentText), LLine));
    finally
      UndoList.EndUpdate();
    end;
  end;

  if (CaretPosition.Char > Length(Lines[CaretPosition.Line].Text)) then
    FCaretPosition.Char := Length(Lines[CaretPosition.Line].Text);
  if (SelBeginPosition.Char > Length(Lines[SelBeginPosition.Line].Text)) then
    FSelBeginPosition.Char := Length(Lines[SelBeginPosition.Line].Text);
  if (SelEndPosition.Char > Length(Lines[SelEndPosition.Line].Text)) then
    FSelEndPosition.Char := Length(Lines[SelEndPosition.Line].Text);
end;

procedure TBCEditorLines.DeleteText(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const ASelMode: TBCEditorSelectionMode = smNormal);
var
  LCaretPosition: TBCEditorTextPosition;
  LBeginText: TBCEditorTextPosition;
  LEndText: TBCEditorTextPosition;
  LEndPosition: TBCEditorTextPosition;
  LInsertBeginPosition: TBCEditorTextPosition;
  LInsertEndPosition: TBCEditorTextPosition;
  LLine: Integer;
  LLineLength: Integer;
  LOldOptions: TOptions;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
  LSpaces: string;
  LText: string;
begin
  UndoList.BeginUpdate();
  try
    if (ABeginPosition = AEndPosition) then
      // Do nothing
    else if (ASelMode = smNormal) then
    begin
      LCaretPosition := CaretPosition;
      LSelBeginPosition := SelBeginPosition;
      LSelEndPosition := SelEndPosition;
      LEndPosition := AEndPosition;

      if (ABeginPosition.Char > Length(Lines[ABeginPosition.Line].Text)) then
      begin
        LInsertBeginPosition := EOLPosition[ABeginPosition.Line];

        LOldOptions := Options;
        FOptions := FOptions - [loTrimTrailingLines, loTrimTrailingSpaces];
        try
          LInsertEndPosition := DoInsertText(LInsertBeginPosition, StringOfChar(BCEDITOR_SPACE_CHAR, ABeginPosition.Char - LInsertBeginPosition.Char));
        finally
          FOptions := LOldOptions;
        end;

        UndoList.PushItem(utInsert, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          LInsertBeginPosition, LInsertEndPosition);

        Assert(LInsertEndPosition = ABeginPosition);
      end
      else if ((loTrimTrailingLines in Options)
        and (Trim(TextBetween[LEndPosition, EOFPosition]) = '')) then
        LEndPosition := EOFPosition;

      LText := GetTextBetween(ABeginPosition, LEndPosition);

      if ((ABeginPosition = BOFPosition) and (LEndPosition = EOFPosition)) then
      begin
        InternalClear(False);

        UndoList.PushItem(utClear, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          ABeginPosition, InvalidPosition, LText);
      end
      else
      begin
        DoDeleteText(ABeginPosition, LEndPosition);

        UndoList.PushItem(utDelete, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          ABeginPosition, InvalidPosition, LText);
      end;
    end
    else
    begin
      LCaretPosition := CaretPosition;
      LSelBeginPosition := SelBeginPosition;
      LSelEndPosition := SelEndPosition;

      UndoList.PushItem(utSelection, LCaretPosition,
        LSelBeginPosition, LSelEndPosition, SelMode,
        InvalidPosition, InvalidPosition);

      for LLine := ABeginPosition.Line to AEndPosition.Line do
      begin
        LBeginText := TextPosition(ABeginPosition.Char, LLine);
        if (AEndPosition.Char < Length(Lines[LLine].Text)) then
          LEndText := EOLPosition[LLine]
        else
          LEndText := TextPosition(AEndPosition.Char, LLine);

        LText := GetTextBetween(LBeginText, LEndText);

        DoDeleteText(LBeginText, LEndText);

        UndoList.PushItem(utDelete, InvalidPosition,
          InvalidPosition, InvalidPosition, SelMode,
          LBeginText, InvalidPosition, LText);

        LLineLength := Length(Lines[LLine].Text);
        if (LLineLength > ABeginPosition.Char) then
        begin
          LSpaces := StringOfChar(BCEDITOR_SPACE_CHAR, ABeginPosition.Char - LLineLength);

          DoInsertText(LEndText, LSpaces);

          UndoList.PushItem(utInsert, InvalidPosition,
            InvalidPosition, InvalidPosition, SelMode,
            TextPosition(ABeginPosition.Char, LLine), TextPosition(AEndPosition.Char, LLine));
        end;
      end;
    end;

    if (SelMode = smNormal) then
      CaretPosition := ABeginPosition;
  finally
    UndoList.EndUpdate();
  end;

  RedoList.Clear();
end;

destructor TBCEditorLines.Destroy;
begin
  FRedoList.Free();
  FUndoList.Free();

  inherited;
end;

procedure TBCEditorLines.DoDelete(ALine: Integer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  if (FMaxLengthLine >= 0) then
    if (FMaxLengthLine = ALine) then
      FMaxLengthLine := -1
    else if (FMaxLengthLine > ALine) then
      Dec(FMaxLengthLine);

  Dec(FCount);
  if (ALine < FCount) then
  begin
    Finalize(Lines[ALine]);
    System.Move(Lines[ALine + 1], Lines[ALine], (FCount - ALine) * SizeOf(Lines[0]));
    FillChar(Lines[FCount], SizeOf(Lines[FCount]), 0);
  end;

  if (SelMode = smNormal) then
    if (Count = 0) then
      CaretPosition := BOFPosition
    else if (ALine < Count) then
      CaretPosition := BOLPosition[ALine]
    else
      CaretPosition := EOLPosition[ALine - 1]
  else
  begin
    if (SelBeginPosition.Line > ALine) then
      SelBeginPosition := TextPosition(SelBeginPosition.Char, SelBeginPosition.Line - 1);
    if (SelEndPosition.Line >= ALine) then
      SelEndPosition := TextPosition(SelEndPosition.Char, SelEndPosition.Line - 1);
  end;

  if (UpdateCount > 0) then
    Include(FState, lsTextChanged);

  if ((Count = 0) and Assigned(OnCleared)) then
    OnCleared(Self)
  else if (Assigned(OnDeleted)) then
    OnDeleted(Self, ALine);
end;

procedure TBCEditorLines.DoDeleteIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
var
  LLine: Integer;
  LTextBeginPosition: TBCEditorTextPosition;
  LTextEndPosition: TBCEditorTextPosition;
begin
  Assert((BOFPosition <= ABeginPosition) and (AEndPosition <= EOFPosition));
  Assert(ABeginPosition <= AEndPosition);

  LTextBeginPosition := BOLPosition[ABeginPosition.Line];
  if (Count = 0) then
    LTextEndPosition := InvalidPosition
  else if (ABeginPosition = AEndPosition) then
    LTextEndPosition := EOLPosition[AEndPosition.Line]
  else if ((AEndPosition.Char = 0) and (AEndPosition.Line > ABeginPosition.Line)) then
    LTextEndPosition := EOLPosition[AEndPosition.Line - 1]
  else
    LTextEndPosition := AEndPosition;

  BeginUpdate();

  try
    for LLine := LTextBeginPosition.Line to LTextEndPosition.Line do
      if (ASelMode = smNormal) then
      begin
        if (LeftStr(Lines[LLine].Text, Length(AIndentText)) = AIndentText) then
          DoPut(LLine, Copy(Lines[LLine].Text, 1 + Length(AIndentText), MaxInt));
      end
      else if (Copy(Lines[LLine].Text, ABeginPosition.Char, Length(AIndentText)) = AIndentText) then
        DoPut(LLine,
          LeftStr(Lines[LLine].Text, ABeginPosition.Char)
            + Copy(Lines[LLine].Text, 1 + ABeginPosition.Char + Length(AIndentText), MaxInt));
  finally
    EndUpdate();
  end;
end;

procedure TBCEditorLines.DoDeleteText(ABeginPosition, AEndPosition: TBCEditorTextPosition);
var
  Line: Integer;
begin
  Assert((BOFPosition <= ABeginPosition) and (AEndPosition <= EOFPosition));
  Assert(ABeginPosition <= AEndPosition);

  if (ABeginPosition = AEndPosition) then
    // Nothing to do...
  else if (ABeginPosition.Line = AEndPosition.Line) then
    DoPut(ABeginPosition.Line, LeftStr(Lines[ABeginPosition.Line].Text, ABeginPosition.Char)
      + Copy(Lines[AEndPosition.Line].Text, 1 + AEndPosition.Char, MaxInt))
  else
  begin
    BeginUpdate();

    try
      DoPut(ABeginPosition.Line, LeftStr(Lines[ABeginPosition.Line].Text, ABeginPosition.Char)
        + Copy(Lines[AEndPosition.Line].Text, 1 + AEndPosition.Char, MaxInt));

      for Line := AEndPosition.Line downto ABeginPosition.Line + 1 do
        DoDelete(Line);
    finally
      EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.DoInsertIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
var
  LEndLine: Integer;
  LLine: Integer;
begin
  Assert((BOFPosition <= ABeginPosition) and (AEndPosition <= EOFPosition));
  Assert(ABeginPosition <= AEndPosition);

  if (Count = 0) then
    LEndLine := -1
  else if ((AEndPosition.Char = 0) and (AEndPosition.Line > ABeginPosition.Line)) then
    LEndLine := AEndPosition.Line - 1
  else
    LEndLine := AEndPosition.Line;

  BeginUpdate();

  try
    for LLine := ABeginPosition.Line to LEndLine do
      if (ASelMode = smNormal) then
        DoPut(LLine, AIndentText + Lines[LLine].Text)
      else if (Length(Lines[LLine].Text) > ABeginPosition.Char) then
        DoPut(LLine, Copy(Lines[LLine].Text, 1, ABeginPosition.Char)
          + AIndentText
          + Copy(Lines[LLine].Text, 1 + ABeginPosition.Char, MaxInt));
  finally
    EndUpdate();
  end;
end;

procedure TBCEditorLines.DoInsert(ALine: Integer; const AText: string);
begin
  Assert((0 <= ALine) and (ALine <= Count));

  if (FCount = FCapacity) then
    Grow();

  if (ALine < FCount) then
    System.Move(Lines[ALine], Lines[ALine + 1], (FCount - ALine) * SizeOf(Lines[0]));
  Inc(FCount);

  Lines[ALine].Attribute.Foreground := clNone;
  Lines[ALine].Attribute.Background := clNone;
  Lines[ALine].Attribute.LineState := lsModified;
  Lines[ALine].ExpandedLength := -1;
  Lines[ALine].FirstRow := -1;
  Lines[ALine].Flags := [sfHasTabs, sfHasNoTabs];
  Lines[ALine].Range := nil;
  Pointer(Lines[ALine].Text) := nil;
  DoPut(ALine, AText);

  if (SelMode = smNormal) then
  begin
    if (ALine < Count - 1) then
      CaretPosition := BOLPosition[ALine + 1]
    else
      CaretPosition := EOLPosition[ALine];
    SelBeginPosition := CaretPosition;
    SelEndPosition := CaretPosition;
  end
  else
  begin
    if (SelBeginPosition.Line < ALine) then
      SelBeginPosition := TextPosition(SelBeginPosition.Char, SelBeginPosition.Line + 1);
    if (SelEndPosition.Line <= ALine) then
      if (ALine < Count) then
        SelEndPosition := EOLPosition[ALine]
      else
        SelEndPosition := TextPosition(SelEndPosition.Char, SelEndPosition.Line + 1);
  end;

  if (UpdateCount > 0) then
    Include(FState, lsTextChanged);
  if (Assigned(OnInserted)) then
    OnInserted(Self, ALine);
end;

function TBCEditorLines.DoInsertText(APosition: TBCEditorTextPosition;
  const AText: string): TBCEditorTextPosition;
var
  LEndPos: PChar;
  LEOL: Boolean;
  LLine: Integer;
  LLineBeginPos: PChar;
  LLineBreak: array [0..2] of Char;
  LLineEnd: string;
  LPos: PChar;
begin
  Assert(BOFPosition <= APosition);
  Assert((APosition.Line < Count) and (APosition.Char <= Length(Lines[APosition.Line].Text)) or (APosition = BOFPosition) and (Count = 0), 'Position: ' + APosition.ToString());

  if (AText = '') then
    Result := APosition
  else if (not HasLineBreak(AText)) then
  begin
    if (Count = 0) then
      DoPut(0, AText)
    else
      DoPut(APosition.Line, LeftStr(Lines[APosition.Line].Text, APosition.Char)
        + AText
        + Copy(Lines[APosition.Line].Text, 1 + APosition.Char, MaxInt));
    Result := TextPosition(APosition.Char + Length(AText), APosition.Line);
  end
  else
  begin
    LLineBreak[0] := #0; LLineBreak[1] := #0; LLineBreak[2] := #0;

    BeginUpdate();

    try
      LLine := APosition.Line;

      LPos := @AText[1];
      LEndPos := @AText[Length(AText)];

      LLineBeginPos := LPos;
      while ((LPos <= LEndPos) and not CharInSet(LPos^, [BCEDITOR_LINEFEED, BCEDITOR_CARRIAGE_RETURN])) do
        Inc(LPos);

      if (LLine < Count) then
      begin
        if (APosition.Char = 0) then
        begin
          LLineEnd := Lines[LLine].Text;
          if (LLineBeginPos < LPos) then
            DoPut(LLine, LeftStr(AText, LPos - LLineBeginPos))
          else if (Lines[LLine].Text <> '') then
            DoPut(LLine, '');
        end
        else
        begin
          LLineEnd := Copy(Lines[LLine].Text, 1 + APosition.Char, MaxInt);
          if (LLineBeginPos < LPos) then
            DoPut(LLine, LeftStr(Lines[LLine].Text, APosition.Char) + LeftStr(AText, LPos - LLineBeginPos))
          else if (Length(Lines[LLine].Text) > APosition.Char) then
            DoPut(LLine, LeftStr(Lines[LLine].Text, APosition.Char));
        end;
      end
      else
        DoInsert(LLine, LeftStr(AText, LPos - LLineBeginPos));
      Inc(LLine);

      if (LPos <= LEndPos) then
      begin
        LLineBreak[0] := LPos^;
        if ((LLineBreak[0] = BCEDITOR_CARRIAGE_RETURN) and (LPos < LEndPos) and (LPos[1] = BCEDITOR_LINEFEED)) then
          LLineBreak[1] := LPos[1];
      end;

      LEOL := (LPos <= LEndPos) and (LPos[0] = LLineBreak[0]) and ((LLineBreak[1] = #0) or (LPos < LEndPos) and (LPos[1] = LLineBreak[1]));
      while (LEOL) do
      begin
        if (LLineBreak[1] = #0) then
          Inc(LPos)
        else
          Inc(LPos, 2);
        LLineBeginPos := LPos;
        repeat
          LEOL := (LPos <= LEndPos) and (LPos[0] = LLineBreak[0]) and ((LLineBreak[1] = #0) or (LPos < LEndPos) and (LPos[1] = LLineBreak[1]));
          if (not LEOL) then
            Inc(LPos);
        until ((LPos > LEndPos) or LEOL);
        if (LEOL) then
        begin
          DoInsert(LLine, Copy(AText, 1 + LLineBeginPos - @AText[1], LPos - LLineBeginPos));
          Inc(LLine);
        end;
      end;

      if (LPos <= LEndPos) then
      begin
        DoInsert(LLine, Copy(AText, LPos - @AText[1], LEndPos + 1 - LPos) + LLineEnd);
        Result := TextPosition(LEndPos + 1 - (LLineBeginPos + 1), LLine);
      end
      else
      begin
        DoInsert(LLine, RightStr(AText, LEndPos + 1 - LLineBeginPos) + LLineEnd);
        Result := TextPosition(1 + LEndPos + 1 - (LLineBeginPos + 1), LLine);
      end;

    finally
      EndUpdate();

      if ((lsLoading in State) and (LLineBreak[0] <> #0)) then
        LineBreak := StrPas(PChar(@LLineBreak[0]));
    end;
  end;
end;

procedure TBCEditorLines.DoPut(ALine: Integer; const AText: string);
var
  LModified: Boolean;
  LLength: Integer;
begin
  if (not (loTrimTrailingSpaces in Options) or (lsLoading in State)) then
    LLength := 0 // ... to avoid compiler warning only
  else
  begin
    LLength := Length(AText);
    while ((LLength > 0) and (AText[LLength] = BCEDITOR_SPACE_CHAR)) do
      Dec(LLength);
  end;

  if ((ALine = 0) and (Count = 0)) then
    if ((loTrimTrailingSpaces in Options) and not (lsLoading in State) and (LLength < Length(AText))) then
      DoInsert(0, Copy(AText, 1, LLength))
    else
      DoInsert(0, AText)
  else
  begin
    Assert((0 <= ALine) and (ALine < Count));

    Lines[ALine].Flags := Lines[ALine].Flags - [sfHasTabs, sfHasNoTabs];
    LModified := False;
    if ((loTrimTrailingSpaces in Options) and not (lsLoading in State) and (LLength < Length(AText))) then
    begin
      if (Copy(AText, 1, LLength) <> Lines[ALine].Text) then
      begin
        Lines[ALine].Text := Copy(AText, 1, LLength);
        Lines[ALine].Attribute.LineState := lsModified;
        LModified := True;
      end;
    end
    else
    begin
      if (AText <> Lines[ALine].Text) then
      begin
        Lines[ALine].Text := AText;
        Lines[ALine].Attribute.LineState := lsModified;
        LModified := True;
      end
    end;

    if (LModified and (FMaxLengthLine >= 0)) then
      if (ExpandedStringLengths[ALine] >= Lines[FMaxLengthLine].ExpandedLength) then
        FMaxLengthLine := ALine
      else if (ALine = FMaxLengthLine) then
        FMaxLengthLine := -1;

    CaretPosition := TextPosition(LLength, ALine);

    if (LModified) then
    begin
      if (UpdateCount > 0) then
        Include(FState, lsTextChanged);
      if (Assigned(OnUpdated)) then
        OnUpdated(Self, ALine);
    end;
  end;
end;

procedure TBCEditorLines.ExchangeItems(ALine1, ALine2: Integer);
var
  LLine: TLine;
begin
  LLine := Lines[ALine1];
  Lines[ALine1] := Lines[ALine2];
  Lines[ALine2] := LLine;
end;

procedure TBCEditorLines.ExecuteUndoRedo(const List: TUndoList);
var
  LPreviousBlockNumber: Integer;
  LCaretPosition: TBCEditorTextPosition;
  LDestinationList: TUndoList;
  LEndPosition: TBCEditorTextPosition;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
  LSelMode: TBCEditorSelectionMode;
  LText: string;
  LUndoItem: TUndoList.PItem;
begin
  if (not ReadOnly and List.PopItem(LUndoItem)) then
  begin
    if (List = UndoList) then
    begin
      Include(FState, lsUndo);
      LDestinationList := RedoList;
    end
    else
    begin
      Include(FState, lsRedo);
      LDestinationList := UndoList;
    end;

    BeginUpdate();

    LCaretPosition := CaretPosition;
    LSelBeginPosition := SelBeginPosition;
    LSelEndPosition := SelEndPosition;
    LSelMode := SelMode;

    repeat
      case (LUndoItem^.UndoType) of
        utSelection:
          begin
            LDestinationList.PushItem(LUndoItem^.UndoType, LCaretPosition,
              LSelBeginPosition, LSelEndPosition, LSelMode,
              LUndoItem^.BeginPosition, LUndoItem^.EndPosition, LUndoItem^.Text, LUndoItem^.BlockNumber);
          end;
        utInsert,
        utReplace,
        utBackspace,
        utDelete:
          begin
            if ((LUndoItem^.BeginPosition <> LUndoItem^.EndPosition)
             and ((LUndoItem^.UndoType in [utReplace])
               or ((LUndoItem^.UndoType in [utBackspace, utDelete]) xor (List = UndoList)))) then
            begin
              LText := GetTextBetween(LUndoItem^.BeginPosition, LUndoItem^.EndPosition);
              DoDeleteText(LUndoItem^.BeginPosition, LUndoItem^.EndPosition);
              if (not (LUndoItem^.UndoType in [utReplace])) then
                LDestinationList.PushItem(LUndoItem^.UndoType, LCaretPosition,
                  LSelBeginPosition, LSelEndPosition, LSelMode,
                  LUndoItem^.BeginPosition, LUndoItem^.EndPosition, LText, LUndoItem^.BlockNumber);
            end
            else
              LText := '';
            if ((LUndoItem^.UndoType in [utReplace])
                or ((LUndoItem^.UndoType in [utBackspace, utDelete]) xor (List <> UndoList))) then
            begin
              if (LUndoItem^.Text = '') then
                LEndPosition := LUndoItem^.BeginPosition
              else
                LEndPosition := DoInsertText(LUndoItem^.BeginPosition, LUndoItem^.Text);
              LDestinationList.PushItem(LUndoItem^.UndoType, LCaretPosition,
                LSelBeginPosition, LSelEndPosition, LSelMode,
                LUndoItem^.BeginPosition, LEndPosition, LText, LUndoItem^.BlockNumber);
            end;
          end;
        utClear:
          if (List = RedoList) then
          begin
            LText := Text;
            FCount := 0;
            LDestinationList.PushItem(LUndoItem^.UndoType, LCaretPosition,
              LSelBeginPosition, LSelEndPosition, LSelMode,
              BOFPosition, InvalidPosition, LText, LUndoItem^.BlockNumber);
          end
          else
          begin
            LEndPosition := DoInsertText(LUndoItem^.BeginPosition, LUndoItem^.Text);
            LDestinationList.PushItem(LUndoItem^.UndoType, LCaretPosition,
              LSelBeginPosition, LSelEndPosition, LSelMode,
              LUndoItem^.BeginPosition, LEndPosition, '', LUndoItem^.BlockNumber);
          end;
        utInsertIndent,
        utDeleteIndent:
          begin
            if ((LUndoItem^.UndoType <> utInsertIndent) xor (List = UndoList)) then
              DoDeleteIndent(LUndoItem^.BeginPosition, LUndoItem^.EndPosition,
                LUndoItem^.Text, LUndoItem^.SelMode)
            else
              DoInsertIndent(LUndoItem^.BeginPosition, LUndoItem^.EndPosition,
                LUndoItem^.Text, LUndoItem^.SelMode);
            LDestinationList.PushItem(LUndoItem^.UndoType, LCaretPosition,
              LSelBeginPosition, LSelEndPosition, LSelMode,
              LUndoItem^.BeginPosition, LUndoItem^.EndPosition, LUndoItem^.Text, LUndoItem^.BlockNumber);
          end;
        else raise ERangeError.Create('UndoType: ' + IntToStr(Ord(LUndoItem^.UndoType)));
      end;

      LCaretPosition := LUndoItem^.CaretPosition;
      LSelBeginPosition := LUndoItem^.SelBeginPosition;
      LSelEndPosition := LUndoItem^.SelEndPosition;
      LSelMode := LUndoItem^.SelMode;

      LPreviousBlockNumber := LUndoItem^.BlockNumber;
    until (not List.PeekItem(LUndoItem)
      or (LUndoItem^.BlockNumber <> LPreviousBlockNumber)
      or not List.PopItem(LUndoItem));

    CaretPosition := LCaretPosition;
    SelBeginPosition := LSelBeginPosition;
    SelEndPosition := LSelEndPosition;
    SelMode := LSelMode;

    EndUpdate();

    if (List = UndoList) then
      Exclude(FState, lsUndo)
    else
      Exclude(FState, lsRedo);
  end;
end;

function TBCEditorLines.Get(ALine: Integer): string;
begin
  Assert((0 <= ALine) and (ALine < Count));

  Result := Lines[ALine].Text;
end;

function TBCEditorLines.GetAttributes(ALine: Integer): PLineAttribute;
begin
  Assert((0 <= ALine) and (ALine < Count));

  Result := @Lines[ALine].Attribute;
end;

function TBCEditorLines.GetBOLPosition(ALine: Integer): TBCEditorTextPosition;
begin
  Result := TextPosition(0, ALine);
end;

function TBCEditorLines.GetCanRedo(): Boolean;
begin
  Result := RedoList.Count > 0;
end;

function TBCEditorLines.GetCanUndo(): Boolean;
begin
  Result := UndoList.Count > 0;
end;

function TBCEditorLines.GetCapacity(): Integer;
begin
  Result := FCapacity;
end;

function TBCEditorLines.GetCount(): Integer;
begin
  Result := FCount;
end;

function TBCEditorLines.GetEOFPosition(): TBCEditorTextPosition;
begin
  if (Count = 0) then
    Result := BOFPosition
  else
    Result := EOLPosition[Count - 1];
end;

function TBCEditorLines.GetEOLPosition(ALine: Integer): TBCEditorTextPosition;
begin
  if (Count = 0) then
    Result := BOFPosition
  else if (ALine < Count) then
    Result := TextPosition(Length(Lines[ALine].Text), ALine)
  else
    Result := BOLPosition[ALine];
end;

function TBCEditorLines.GetExpandedString(ALine: Integer): string;
begin
  Assert((0 <= ALine) and (ALine < Count));

  if (sfHasNoTabs in Lines[ALine].Flags) then
    Result := Lines[ALine].Text
  else
    Result := CalcExpandString(ALine);
end;

function TBCEditorLines.GetExpandedStringLength(ALine: Integer): Integer;
begin
  Assert((0 <= ALine) and (ALine < Count));

  if (Lines[ALine].ExpandedLength >= 0) then
    Lines[ALine].ExpandedLength := Length(ExpandedStrings[ALine]);
  Result := Lines[ALine].ExpandedLength;
end;

function TBCEditorLines.GetMaxLength(): Integer;
var
  I: Integer;
  LMaxLength: Integer;
  Line: ^TLine;
begin
  if (FMaxLengthLine < 0) then
  begin
    LMaxLength := 0;
    if (FCount > 0) then
    begin
      Line := @Lines[0];
      for I := 0 to Count - 1 do
      begin
        if (Line^.ExpandedLength < 0) then
          CalcExpandString(I);
        if (Line^.ExpandedLength > LMaxLength) then
        begin
          LMaxLength := Line^.ExpandedLength;
          FMaxLengthLine := I;
        end;
        Inc(Line);
      end;
    end;
  end;

  if (FMaxLengthLine < 0) then
    Result := 0
  else
    Result := Lines[FMaxLengthLine].ExpandedLength;
end;

function TBCEditorLines.GetFirstRow(ALine: Integer): Integer;
begin
  Assert((0 <= ALine) and (ALine < Count));

  Result := Lines[ALine].FirstRow;
end;

function TBCEditorLines.GetRange(ALine: Integer): TRange;
begin
  Assert((0 <= ALine) and (ALine < Count));

  Result := Lines[ALine].Range;
end;

function TBCEditorLines.GetTextBetween(const ABeginPosition, AEndPosition: TBCEditorTextPosition): string;
var
  LLine: Integer;
  StringBuilder: TStringBuilder;
begin
  Assert((BOFPosition <= ABeginPosition) and (AEndPosition <= EOFPosition));
  Assert(ABeginPosition <= AEndPosition);
  Assert(ABeginPosition.Char <= Length(Lines[ABeginPosition.Line].Text));
  Assert(AEndPosition.Char <= Length(Lines[AEndPosition.Line].Text));

  if (ABeginPosition = AEndPosition) then
    Result := ''
  else if (ABeginPosition.Line = AEndPosition.Line) then
    Result := Copy(Lines[ABeginPosition.Line].Text, 1 + ABeginPosition.Char, AEndPosition.Char - ABeginPosition.Char)
  else
  begin
    StringBuilder := TStringBuilder.Create();

    StringBuilder.Append(Lines[ABeginPosition.Line].Text, ABeginPosition.Char, Length(Lines[ABeginPosition.Line].Text) - ABeginPosition.Char);
    for LLine := ABeginPosition.Line + 1 to AEndPosition.Line - 1 do
    begin
      StringBuilder.Append(LineBreak);
      StringBuilder.Append(Lines[LLine].Text);
    end;
    StringBuilder.Append(LineBreak);
    StringBuilder.Append(Lines[AEndPosition.Line].Text, 0, AEndPosition.Char);

    Result := StringBuilder.ToString();

    StringBuilder.Free();
  end;
end;

function TBCEditorLines.GetTextBetweenColumn(const ABeginPosition, AEndPosition: TBCEditorTextPosition): string;
var
  StringBuilder: TStringBuilder;
  LBeginPosition: TBCEditorTextPosition;
  LEndPosition: TBCEditorTextPosition;
  LLine: Integer;
begin
  Assert(ABeginPosition <= LEndPosition);
  Assert(ABeginPosition.Char <= Length(Lines[ABeginPosition.Line].Text));

  LBeginPosition := Min(ABeginPosition, LEndPosition);
  LEndPosition := Max(ABeginPosition, LEndPosition);

  if (LBeginPosition = LEndPosition) then
    Result := ''
  else if (LBeginPosition.Line = LEndPosition.Line) then
    Result := Copy(Lines[LBeginPosition.Line].Text, 1 + LBeginPosition.Char, LEndPosition.Char - LBeginPosition.Char)
  else
  begin
    StringBuilder := TStringBuilder.Create();

    for LLine := LBeginPosition.Line to LEndPosition.Line do
    begin
      if (Length(Lines[LBeginPosition.Line].Text) < LBeginPosition.Char) then
        // Do nothing
      else if (Length(Lines[LBeginPosition.Line].Text) < LEndPosition.Char) then
        StringBuilder.Append(Copy(Lines[LBeginPosition.Line].Text, LBeginPosition.Char, Length(Lines[LBeginPosition.Line].Text) - LBeginPosition.Char))
      else
        StringBuilder.Append(Copy(Lines[LBeginPosition.Line].Text, LBeginPosition.Char, LEndPosition.Char - LBeginPosition.Char + 1));
      if (LLine < LEndPosition.Line) then
        StringBuilder.Append(LineBreak);
    end;

    Result := StringBuilder.ToString();

    StringBuilder.Free();
  end;
end;

function TBCEditorLines.GetTextLength(): Integer;
var
  i: Integer;
  LLineBreakLength: Integer;
begin
  Result := 0;
  LLineBreakLength := Length(LineBreak);
  for i := 0 to FCount - 1 do
  begin
    if i = FCount - 1 then
      LLineBreakLength := 0;
    Inc(Result, Length(Lines[i].Text) + LLineBreakLength)
  end;
end;

function TBCEditorLines.GetTextStr: string;
begin
  if (Count = 0) then
    Result := ''
  else
    Result := GetTextBetween(BOFPosition, EOFPosition);
end;

procedure TBCEditorLines.Grow();
begin
  if Capacity > 64 then
    Capacity := Capacity + FCapacity div 4
  else
    Capacity := Capacity + 16;
end;

procedure TBCEditorLines.Insert(ALine: Integer; const AText: string);
var
  LCaretPosition: TBCEditorTextPosition;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
begin
  LCaretPosition := CaretPosition;
  LSelBeginPosition := SelBeginPosition;
  LSelEndPosition := SelEndPosition;

  DoInsert(ALine, AText);

  if (not (lsLoading in State)) then
  begin
    UndoList.PushItem(utInsert, LCaretPosition,
      LSelBeginPosition, LSelEndPosition, SelMode,
      BOLPosition[ALine], TextPosition(Length(AText), ALine));

    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.InsertIndent(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const AIndentText: string; const ASelMode: TBCEditorSelectionMode);
var
  LBeginPosition: TBCEditorTextPosition;
  LCaretPosition: TBCEditorTextPosition;
  LEndPosition: TBCEditorTextPosition;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
begin
  LBeginPosition := Min(ABeginPosition, AEndPosition);
  LEndPosition := Max(ABeginPosition, AEndPosition);

  LCaretPosition := CaretPosition;
  LSelBeginPosition := SelBeginPosition;
  LSelEndPosition := SelBeginPosition;

  DoInsertIndent(LBeginPosition, LEndPosition, AIndentText, ASelMode);

  UndoList.PushItem(utInsertIndent, LCaretPosition,
    LSelBeginPosition, LSelEndPosition, SelMode,
    LBeginPosition, LEndPosition, AIndentText);

  RedoList.Clear();
end;

procedure TBCEditorLines.InsertText(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const AText: string);
var
  LCaretPosition: TBCEditorTextPosition;
  LDeleteText: string;
  LEndPos: PChar;
  LInsertBeginPosition: TBCEditorTextPosition;
  LInsertEndPosition: TBCEditorTextPosition;
  LInsertText: string;
  LLine: Integer;
  LLineBeginPos: PChar;
  LLineLength: Integer;
  LPos: PChar;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
begin
  Assert(ABeginPosition.Char < AEndPosition.Char);
  Assert(ABeginPosition.Line <= AEndPosition.Line);

  LCaretPosition := CaretPosition;
  LSelBeginPosition := SelBeginPosition;
  LSelEndPosition := SelEndPosition;

  BeginUpdate();

  try
    LPos := PChar(AText);
    LEndPos := @LPos[Length(AText)];
    LLine := ABeginPosition.Line;

    while ((LPos <= LEndPos) or (LLine <= AEndPosition.Line)) do
    begin
      LLineBeginPos := LPos;
      while ((LPos <= LEndPos) and not CharInSet(LPos^, [BCEDITOR_LINEFEED, BCEDITOR_CARRIAGE_RETURN])) do
        Inc(LPos);

      LLineLength := Length(Lines[LLine].Text);
      SetString(LInsertText, LLineBeginPos, LPos - LLineBeginPos);
      if (LLineLength < ABeginPosition.Char) then
      begin
        LInsertText := StringOfChar(BCEDITOR_SPACE_CHAR, ABeginPosition.Char - LLineLength) + LInsertText;

        LInsertBeginPosition := TextPosition(LLineLength, LLine);
        LInsertEndPosition := InsertText(LInsertBeginPosition, LInsertText);

        UndoList.PushItem(utInsert, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          LInsertBeginPosition, LInsertEndPosition);
      end
      else if (LLineLength < AEndPosition.Char) then
      begin
        LInsertBeginPosition := TextPosition(ABeginPosition.Char, LLine);

        LDeleteText := GetTextBetween(LInsertBeginPosition, TextPosition(LLineLength, LLine));
        DeleteText(LInsertBeginPosition, LInsertEndPosition);

        UndoList.PushItem(utDelete, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          LInsertBeginPosition, InvalidPosition, LDeleteText);

        if (LPos > LLineBeginPos) then
        begin
          LInsertEndPosition := InsertText(LInsertBeginPosition, LInsertText);

          UndoList.PushItem(utInsert, InvalidPosition,
            InvalidPosition, InvalidPosition, SelMode,
            LInsertBeginPosition, LInsertEndPosition);
        end;
      end
      else
      begin
        LInsertBeginPosition := TextPosition(ABeginPosition.Char, LLine);
        LInsertEndPosition := TextPosition(AEndPosition.Char, LLine);

        LDeleteText := GetTextBetween(LInsertBeginPosition, LInsertEndPosition);
        DeleteText(LInsertBeginPosition, LInsertEndPosition);

        UndoList.PushItem(utDelete, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          LInsertBeginPosition, InvalidPosition, LDeleteText);

        if (LPos > LLineBeginPos) then
        begin
          LInsertEndPosition := InsertText(LInsertBeginPosition, LeftStr(LInsertText, AEndPosition.Char - ABeginPosition.Char));

          UndoList.PushItem(utInsert, LCaretPosition,
            InvalidPosition, InvalidPosition, SelMode,
            LInsertBeginPosition, LInsertEndPosition);
        end;
      end;

      if ((LPos <= LEndPos) and (LPos^ = BCEDITOR_LINEFEED)) then
        Inc(LPos)
      else if ((LPos <= LEndPos) and (LPos^ = BCEDITOR_CARRIAGE_RETURN)) then
      begin
        Inc(LPos);
        if ((LPos <= LEndPos) and (LPos^ = BCEDITOR_LINEFEED)) then
          Inc(LPos);
      end;

      Inc(LLine);
    end;

  finally
    RedoList.Clear();
    EndUpdate();
  end;
end;

function TBCEditorLines.InsertText(APosition: TBCEditorTextPosition;
  const AText: string): TBCEditorTextPosition;
var
  LCaretPosition: TBCEditorTextPosition;
  LIndex: Integer;
  LPosition: TBCEditorTextPosition;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
  LText: string;
begin
  BeginUpdate();
  try
    if (AText = '') then
      Result := APosition
    else
    begin
      LCaretPosition := CaretPosition;
      LSelBeginPosition := SelBeginPosition;
      LSelEndPosition := SelEndPosition;
      if (Count = 0) then
      begin
        LPosition := BOFPosition;
        LText := '';
        for LIndex := 1 to APosition.Line do
          LText := LText + LineBreak;
        LText := LText + StringOfChar(BCEDITOR_SPACE_CHAR, APosition.Char);
        Result := DoInsertText(LPosition, LText + AText);
      end
      else if ((APosition.Line < Count) and (APosition.Char <= Length(Lines[APosition.Line].Text))) then
      begin
        LPosition := APosition;
        Result := DoInsertText(LPosition, AText);
      end
      else if (APosition.Line < Count) then
      begin
        LPosition := EOLPosition[APosition.Line];
        Result := DoInsertText(LPosition, StringOfChar(BCEDITOR_SPACE_CHAR, APosition.Char - LPosition.Char) + AText);
      end
      else
      begin
        LPosition := EOLPosition[Count - 1];
        LText := '';
        for LIndex := Count to APosition.Line do
          LText := LText + LineBreak;
        LText := LText + StringOfChar(BCEDITOR_SPACE_CHAR, APosition.Char);
        Result := DoInsertText(LPosition, LText + AText);
      end;

      UndoList.PushItem(utInsert, LCaretPosition,
        LSelBeginPosition, LSelEndPosition, SelMode,
        APosition, Result);
    end;

    if (SelMode = smNormal) then
      CaretPosition := Result;
  finally
    EndUpdate();
    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.InternalClear(const AClearUndo: Boolean);
begin
  if (AClearUndo) then
    ClearUndo();

  FMaxLengthLine := -1;
  LineBreak := BCEDITOR_CARRIAGE_RETURN + BCEDITOR_LINEFEED;
  if (Capacity > 0) then
  begin
    FCaretPosition := BOFPosition;
    FSelBeginPosition := BOFPosition;
    FSelEndPosition := BOFPosition;
    Capacity := 0;
    if (Assigned(OnCleared)) then
      OnCleared(Self);
  end;
end;

function TBCEditorLines.IsPositionInSelection(const APosition: TBCEditorTextPosition): Boolean;
begin
  if (SelMode = smNormal) then
    Result := (SelBeginPosition <= APosition) and (APosition <= SelEndPosition)
  else
    Result := (SelBeginPosition.Char <= APosition.Char) and (APosition.Char <= SelEndPosition.Char)
      and (SelBeginPosition.Line <= APosition.Line) and (APosition.Line <= SelEndPosition.Line);
end;

procedure TBCEditorLines.Put(ALine: Integer; const AText: string);
var
  LTrailingLines: Boolean;
begin
  LTrailingLines := (ALine = Count - 1) and (loTrimTrailingLines in Options);

  if (LTrailingLines) then
  begin
    LTrailingLines := True;
    BeginUpdate();
  end;

  try
    if ((FCount = 0) and (ALine = 0)) then
      Add(AText)
    else if (AText <> Lines[ALine].Text) then
      ReplaceText(BOLPosition[ALine], EOLPosition[ALine], AText);

  finally
    if (LTrailingLines) then
    try
      while ((Count > 0) and (Lines[Count - 1].Text = '')) do
        Delete(Count - 1);
    finally
      EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.PutAttributes(ALine: Integer; const AValue: PLineAttribute);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Lines[ALine].Attribute := AValue^;
end;

procedure TBCEditorLines.PutFirstRow(ALine: Integer; const ARow: Integer);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Lines[ALine].FirstRow := ARow;
end;

procedure TBCEditorLines.PutRange(ALine: Integer; ARange: TRange);
begin
  Assert((0 <= ALine) and (ALine < Count));

  Lines[ALine].Range := ARange;
end;

procedure TBCEditorLines.QuickSort(ALeft, ARight: Integer; ACompare: TCompare);
var
  LLeft: Integer;
  LMiddle: Integer;
  LRight: Integer;
begin
  repeat
    LLeft := ALeft;
    LRight := ARight;
    LMiddle := (ALeft + ARight) shr 1;
    repeat
      while ACompare(Self, LLeft, LMiddle) < 0 do
        Inc(LLeft);
      while ACompare(Self, LRight, LMiddle) > 0 do
        Dec(LRight);
      if LLeft <= LRight then
      begin
        if LLeft <> LRight then
          ExchangeItems(LLeft, LRight);
        if LMiddle = LLeft then
          LMiddle := LRight
        else
        if LMiddle = LRight then
          LMiddle := LLeft;
        Inc(LLeft);
        Dec(LRight);
      end;
    until LLeft > LRight;
    if ALeft < LRight then
      QuickSort(ALeft, LRight, ACompare);
    ALeft := LLeft;
  until LLeft >= ARight;
end;

procedure TBCEditorLines.Redo();
begin
  ExecuteUndoRedo(RedoList);
end;

function TBCEditorLines.ReplaceText(ABeginPosition, AEndPosition: TBCEditorTextPosition;
  const AText: string): TBCEditorTextPosition;
var
  LBeginPosition: TBCEditorTextPosition;
  LCaretPosition: TBCEditorTextPosition;
  LOldOptions: TOptions;
  LSelBeginPosition: TBCEditorTextPosition;
  LSelEndPosition: TBCEditorTextPosition;
  LText: string;
begin
  if (ABeginPosition = AEndPosition) then
    InsertText(ABeginPosition, AText)
  else
  begin
    UndoList.BeginUpdate();
    try
      LCaretPosition := CaretPosition;
      LSelBeginPosition := SelBeginPosition;
      LSelEndPosition := SelEndPosition;

      if ((AText = '')
        and (ABeginPosition.Char = 0)
        and (AEndPosition = EOFPosition)
        and (loTrimTrailingLines in Options)) then
      begin
        LBeginPosition := ABeginPosition;
        while ((LBeginPosition.Line > 0) and (Lines[LBeginPosition.Line - 1].Text = '')) do
          Dec(LBeginPosition.Line);
        if (LBeginPosition = BOFPosition) then
        begin
          InternalClear(False);
          Result := BOFPosition;

          UndoList.PushItem(utClear, LCaretPosition,
            LSelBeginPosition, LSelEndPosition, SelMode,
            ABeginPosition, InvalidPosition, LText);
        end
        else
        begin
          LText := TextBetween[LBeginPosition, AEndPosition];

          DoDeleteText(LBeginPosition, AEndPosition);
          Result := LBeginPosition;

          UndoList.PushItem(utDelete, LCaretPosition,
            LSelBeginPosition, LSelEndPosition, SelMode,
            LBeginPosition, AEndPosition, LText);
        end;
      end
      else
      begin
        LText := TextBetween[ABeginPosition, AEndPosition];

        LOldOptions := FOptions;
        try
          FOptions := FOptions - [loTrimTrailingLines, loTrimTrailingSpaces];
          DoDeleteText(ABeginPosition, AEndPosition);
        finally
          FOptions := LOldOptions;
        end;
        Result := DoInsertText(ABeginPosition, AText);

        UndoList.PushItem(utReplace, LCaretPosition,
          LSelBeginPosition, LSelEndPosition, SelMode,
          ABeginPosition, Result, LText);
      end;

      CaretPosition := Result;
    finally
      UndoList.EndUpdate();
    end;
  end;
end;

procedure TBCEditorLines.SaveToStream(AStream: TStream; AEncoding: TEncoding);
begin
  inherited;

  if (not (loUndoAfterSave in Options)) then
  begin
    UndoList.Clear();
    RedoList.Clear();
  end;
end;

procedure TBCEditorLines.SetCapacity(AValue: Integer);
begin
  Assert(AValue >= 0);

  if (AValue <> FCapacity) then
  begin
    SetLength(FLines, AValue);
    FCapacity := AValue;
    FCount := Min(FCount, FCapacity);
  end;
end;

procedure TBCEditorLines.SetCaretPosition(const AValue: TBCEditorTextPosition);
begin
  Assert(BOFPosition <= AValue);

  if (AValue <> FCaretPosition) then
  begin
    BeginUpdate();

    FCaretPosition := AValue;

    SelBeginPosition := AValue;

    Include(FState, lsCaretMoved);
    EndUpdate();
  end
  else
    SelBeginPosition := AValue;
end;

procedure TBCEditorLines.SetModified(const AValue: Boolean);
var
  LLine: Integer;
begin
  if (FModified <> AValue) then
  begin
    FModified := AValue;

    if (not FModified) then
    begin
      UndoList.GroupBreak();

      BeginUpdate();
      for LLine := 0 to Count - 1 do
        if (Lines[LLine].Attribute.LineState = lsModified) then
          Lines[LLine].Attribute.LineState := lsSaved;
      EndUpdate();
      Editor.Invalidate();
    end;
  end;
end;

procedure TBCEditorLines.SetOptions(const AValue: TOptions);
var
  LLine: Integer;
begin
  if (not (loTrimTrailingSpaces in Options) and (loTrimTrailingSpaces in Options)) then
    for LLine := 0 to Count - 1 do
      if ((Lines[LLine].Text <> '') and (Lines[LLine].Text[Length(Lines[LLine].Text)] = BCEDITOR_SPACE_CHAR)) then
        DoPut(LLine, Lines[LLine].Text);

  FOptions := AValue;
end;

procedure TBCEditorLines.SetSelBeginPosition(const AValue: TBCEditorTextPosition);
begin
  Assert(BOFPosition <= AValue);

  if (AValue <> FSelBeginPosition) then
  begin
    BeginUpdate();

    FSelBeginPosition := AValue;
    if (SelMode = smNormal) then
      if (Count = 0) then
        FSelBeginPosition := BOFPosition
      else if (FSelBeginPosition.Line < Count) then
        FSelBeginPosition.Char := Min(FSelBeginPosition.Char, Length(Lines[FSelBeginPosition.Line].Text))
      else
        FSelBeginPosition := EOFPosition;

    SelEndPosition := AValue;

    Include(FState, lsSelChanged);
    EndUpdate();
  end
  else
    SelEndPosition := AValue;
end;

procedure TBCEditorLines.SetSelEndPosition(const AValue: TBCEditorTextPosition);
begin
  Assert(BOFPosition <= AValue);

  if (AValue <> FSelEndPosition) then
  begin
    BeginUpdate();

    FSelEndPosition := AValue;
    if (SelMode = smNormal) then
      if (Count = 0) then
        FSelEndPosition := BOFPosition
      else if (FSelEndPosition.Line < Count) then
        FSelEndPosition.Char := Min(FSelEndPosition.Char, Length(Lines[FSelEndPosition.Line].Text))
      else
        FSelEndPosition := EOFPosition;

    Include(FState, lsSelChanged);
    EndUpdate();
  end;
end;

procedure TBCEditorLines.SetTabWidth(const AValue: Integer);
var
  LIndex: Integer;
begin
  if FTabWidth <> AValue then
  begin
    FTabWidth := AValue;
    FMaxLengthLine := -1;
    for LIndex := 0 to FCount - 1 do
      with Lines[LIndex] do
      begin
        ExpandedLength := -1;
        Exclude(Flags, sfHasNoTabs);
      end;
  end;
end;

procedure TBCEditorLines.SetTextStr(const AValue: string);
var
  LEndPosition: TBCEditorTextPosition;
  LLine: Integer;
begin
  Include(FState, lsLoading);

  if (not (csReading in Editor.ComponentState) and Assigned(OnBeforeLoad)) then
    OnBeforeLoad(Self);

  BeginUpdate();

  if (loUndoAfterLoad in Options) then
    DeleteText(BOFPosition, EOFPosition);

  InternalClear(not (loUndoAfterLoad in Options));

  LEndPosition := InsertText(BOFPosition, AValue);
  for LLine := 0 to Count - 1 do
    Attributes[LLine].LineState := lsLoaded;

  if (loUndoAfterLoad in Options) then
  begin
    UndoList.PushItem(utInsert, BOFPosition,
      InvalidPosition, InvalidPosition, SelMode,
      BOFPosition, LEndPosition);

    RedoList.Clear();
  end;

  CaretPosition := BOFPosition;

  EndUpdate();

  if (not (csReading in Editor.ComponentState) and Assigned(OnAfterLoad)) then
    OnAfterLoad(Self);

  Exclude(FState, lsLoading);
end;

procedure TBCEditorLines.SetUpdateState(AUpdating: Boolean);
begin
  if (AUpdating) then
  begin
    UndoList.BeginUpdate();
    FState := FState - [lsCaretMoved, lsSelChanged, lsTextChanged];
    FOldUndoListCount := UndoList.Count;
    FOldCaretPosition := CaretPosition;
    FOldSelBeginPosition := SelBeginPosition;
    FOldSelEndPosition := SelEndPosition;
  end
  else
  begin
    if (not (lsRedo in State) and ((lsCaretMoved in State) or (lsSelChanged in State)) and not UndoList.Updated) then
    begin
      if (not (lsUndo in State)) then
      begin
        if ((UndoList.Count = FOldUndoListCount)
          and (CaretPosition <> FOldCaretPosition)
            or (SelBeginPosition <> FOldSelBeginPosition)
            or (SelEndPosition <> FOldSelBeginPosition)) then
          UndoList.PushItem(utSelection, FOldCaretPosition,
            FOldSelBeginPosition, FOldSelEndPosition, SelMode,
            InvalidPosition, InvalidPosition);
        RedoList.Clear();
      end;
    end;

    UndoList.EndUpdate();

    if (Assigned(OnCaretMoved) and (lsCaretMoved in FState)) then
      OnCaretMoved(Self);
    if (Assigned(OnSelChange) and (lsSelChanged in FState)) then
      OnSelChange(Self);

    FState := FState - [lsCaretMoved, lsSelChanged, lsTextChanged];
  end;
end;

procedure TBCEditorLines.Sort(const ABeginLine, AEndLine: Integer);
begin
  CustomSort(ABeginLine, AEndLine, CompareLines);
end;

function TBCEditorLines.PositionToCharIndex(const APosition: TBCEditorTextPosition): Integer;
var
  LLine: Integer;
  LLineBreakLength: Integer;
begin
  LLineBreakLength := Length(LineBreak);
  Result := 0;
  for LLine := 0 to APosition.Line - 1 do
  begin
    Inc(Result, Length(Lines[LLine].Text));
    Inc(Result, LLineBreakLength);
  end;
  Inc(Result, APosition.Char);
end;

procedure TBCEditorLines.Undo();
begin
  ExecuteUndoRedo(UndoList);
end;

procedure TBCEditorLines.UndoGroupBreak();
begin
  if ((loUndoGrouped in Options) and CanUndo) then
    UndoList.GroupBreak();
end;

end.


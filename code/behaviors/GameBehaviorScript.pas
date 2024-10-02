unit GameBehaviorScript;

interface

uses
  SysUtils, Classes,
  {$ifdef CASTLE_DESIGN_MODE}
  PropEdits, CastlePropEdits, CastleDebugTransform,
  {$endif}
  CastleBehaviors, CastleTransform, CastleVectors, CastleScene, CastleComponentSerialize,
  CastleApplicationProperties, CastleClassUtils, CastleDownload, CastleLog, CastleUtils,
  ScriptEngine;

type
  TBehaviorScript = class(TCastleBehavior)
  private
    procedure SetURL(Value: String);
    procedure SetScript(Value: TStrings);

    function SEWarn(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SETranslationSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SETranslationGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SERotationSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SERotationGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SEScaleSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SEScaleGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SEDirectionSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
    function SEDirectionGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
  protected
    FIsInit: Boolean;
    FIsRun: Boolean;
    FSE: TScriptEngine;
    FScript: TStrings;
    FURL: String;
    FSkipTimeInMSec: QWord;
    FCurTicks: QWord;
    FLastTicks: QWord;
    procedure InitSE(const IsParsedOnly: Boolean);
    function PropertySections(const PropertyName: String): TPropertySections; override;
  public
    Storage: TSEValue;
    PasObjectSelf: TSEValue;
    PasObjectParent: TSEValue;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
  published
    property Script: TStrings read FScript write SetScript;
    property URL: String read FURL write SetURL;
    property SkipTimeInMSec: QWord read FSkipTimeInMSec write FSkipTimeInMSec;
  end;

implementation

constructor TBehaviorScript.Create(AOwner: TComponent);
begin
  inherited;
  Self.FScript := TStringList.Create;
  Self.FLastTicks := GetTickCount64;
  Self.FCurTicks := Self.FLastTicks;

  Self.Name := 'behavior_' + IntToStr(Random($FFFFFFFFFFFFFFFF));
  Self.FSE := TScriptEngine.Create;
  Self.FSE.RegisterFunc('warn', @Self.SEWarn, 1);
  Self.FSE.RegisterFunc('translation_get', @Self.SETranslationGet, 0);
  Self.FSE.RegisterFunc('translation_set', @Self.SETranslationSet, 3);
  Self.FSE.RegisterFunc('rotation_get', @Self.SERotationGet, 0);
  Self.FSE.RegisterFunc('rotation_set', @Self.SERotationSet, 4);
  Self.FSE.RegisterFunc('scale_get', @Self.SEScaleGet, 0);
  Self.FSE.RegisterFunc('scale_set', @Self.SEScaleSet, 3);
  Self.FSE.RegisterFunc('direction_get', @Self.SEDirectionGet, 0);
  Self.FSE.RegisterFunc('direction_set', @Self.SEDirectionSet, 3);
end;

destructor TBehaviorScript.Destroy;
begin
  {$ifdef CASTLE_DESIGN_MODE}
  if InternalCastleApplicationMode = appSimulation then
  {$endif}
    Self.FSE.ExecFunc('destroy', []);
  Self.FScript.Free;
  Self.FSE.Free;
  inherited;
end;

procedure TBehaviorScript.InitSE(const IsParsedOnly: Boolean);
var
  MS: TStream;
  SS: TStringStream;
begin
  if Self.Script.Text <> '' then
    Self.FSE.Source := Self.Script.Text
  else
  if Self.URL <> '' then
  begin
    MS := Download(Self.URL);
    SS := TStringStream.Create('');
    try
      MS.Position := 0;
      SS.CopyFrom(MS, MS.Size);
      Self.FSE.Source := SS.DataString;
    finally
      FreeAndNil(SS);
      FreeAndNil(MS);
    end;
  end else
    Self.FSE.Source := '';
  try
    Self.FSE.ConstMap.AddOrSetValue('name', Self.Name);
    //
    GC.AllocMap(@Storage);
    ScriptVarMap.AddOrSetValue(Self.Name, Storage);
    // We pass self and parent to the script engine's storage
    GC.AllocPascalObject(@PasObjectSelf, Self, False);
    GC.AllocPascalObject(@PasObjectParent, Self.Parent, False);
    SEMapSet(Storage, 'self', PasObjectSelf);
    SEMapSet(Storage, 'parent', PasObjectParent);
    if IsParsedOnly then
    begin
      Self.FSE.Lex;
      Self.FSE.Parse;
    end else
      Self.FSE.Exec;
  except
    on E: Exception do
    begin
      WritelnWarning('[Script] ' + Self.Name, E.Message);
    end;
  end;
end;

procedure TBehaviorScript.SetURL(Value: String);
begin
  Self.FURL := Value;
  Self.InitSE({$ifdef CASTLE_DESIGN_MODE}True{$else}False{$endif});
end;

procedure TBehaviorScript.SetScript(Value: TStrings);
begin
  Self.FScript.Assign(Value);
  Self.InitSE({$ifdef CASTLE_DESIGN_MODE}True{$else}False{$endif});
end;

function TBehaviorScript.SEWarn(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
begin
  WritelnWarning('[Script] ' + Self.Name, SEValueToText(Args[0]));
end;

function TBehaviorScript.SETranslationSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
begin
  Self.Parent.Translation := Vector3(Args[0].VarNumber, Args[1].VarNumber, Args[2].VarNumber);
end;

function TBehaviorScript.SETranslationGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
var
  V: TVector3;
begin
  V := Self.Parent.Translation;
  GC.AllocMap(@Result);
  SEMapSet(Result, 'x', V.X);
  SEMapSet(Result, 'y', V.Y);
  SEMapSet(Result, 'z', V.Z);
end;

function TBehaviorScript.SERotationSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
begin
  Self.Parent.Rotation := Vector4(Args[0].VarNumber, Args[1].VarNumber, Args[2].VarNumber, Args[3].VarNumber);
end;

function TBehaviorScript.SERotationGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
var
  V: TVector4;
begin
  V := Self.Parent.Rotation;
  GC.AllocMap(@Result);
  SEMapSet(Result, 'x', V.X);
  SEMapSet(Result, 'y', V.Y);
  SEMapSet(Result, 'z', V.Z);
  SEMapSet(Result, 'w', V.W);
end;

function TBehaviorScript.SEScaleSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
begin
  Self.Parent.Scale := Vector3(Args[0].VarNumber, Args[1].VarNumber, Args[2].VarNumber);
end;

function TBehaviorScript.SEScaleGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
var
  V: TVector3;
begin
  V := Self.Parent.Scale;
  GC.AllocMap(@Result);
  SEMapSet(Result, 'x', V.X);
  SEMapSet(Result, 'y', V.Y);
  SEMapSet(Result, 'z', V.Z);
end;

function TBehaviorScript.SEDirectionSet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
begin
  Self.Parent.Scale := Vector3(Args[0].VarNumber, Args[1].VarNumber, Args[2].VarNumber);
end;

function TBehaviorScript.SEDirectionGet(const VM: TSEVM; const Args: array of TSEValue): TSEValue;
var
  V: TVector3;
begin
  V := Self.Parent.Direction;
  GC.AllocMap(@Result);
  SEMapSet(Result, 'x', V.X);
  SEMapSet(Result, 'y', V.Y);
  SEMapSet(Result, 'z', V.Z);
end;

function TBehaviorScript.PropertySections(const PropertyName: String): TPropertySections;
begin
  if (PropertyName = 'URL')
    or (PropertyName = 'Script') then
    Result := [psBasic]
  else
    Result := inherited PropertySections(PropertyName);
end;

procedure TBehaviorScript.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  IsRemoved: Boolean = False;
  MSecPassed: QWord;
begin
  {$ifdef CASTLE_DESIGN_MODE}
  if Self.FIsRun and not (InternalCastleApplicationMode in [appSimulation, appSimulationPaused]) then
  begin
    Self.FIsInit := False;
    Self.FIsRun := False;
  end;
  {$endif}
  {$ifdef CASTLE_DESIGN_MODE}
  if InternalCastleApplicationMode = appSimulation then
  {$endif}
  begin
    if not Self.FIsInit then
    begin
      Self.InitSE(False);
      Self.FIsInit := True;
    end;
  end;
  inherited;
  //
  {$ifdef CASTLE_DESIGN_MODE}
  if InternalCastleApplicationMode = appSimulation then
  {$endif}
  begin
    MSecPassed := Self.FCurTicks - Self.FLastTicks;
    if MSecPassed >= Self.FSkipTimeInMSec then
    begin
      try
        IsRemoved := Self.FSE.ExecFunc('update', [MSecPassed / 1000]).VarBoolean;
      except
        on E: Exception do
        begin
          WritelnWarning('[Script] ' + Self.Name, E.Message);
        end;
      end;
      Self.FLastTicks := Self.FCurTicks;
    end;
    Self.FIsRun := True;
  end;
  {$ifdef CASTLE_DESIGN_MODE}
  if InternalCastleApplicationMode = appSimulationPaused then
    Self.FLastTicks := Self.FCurTicks;
  {$endif}
  //
  {$ifdef CASTLE_DESIGN_MODE}
  if InternalCastleApplicationMode = appSimulation then
  {$endif}
    Self.FCurTicks := Self.FCurTicks + Round(SecondsPassed * 1000);
  if IsRemoved then
    RemoveMe := rtRemoveAndFree;
end;

initialization
  {$ifdef CASTLE_DESIGN_MODE}
  RegisterPropertyEditor(TypeInfo(AnsiString), TBehaviorScript,
    'URL', TSceneURLPropertyEditor);
  {$endif}
  RegisterSerializableComponent(TBehaviorScript, 'Script');

end.
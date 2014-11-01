library SCSTelemetry_ServerLogger;

{$INCLUDE '..\..\..\Source\Telemetry_defs.inc'}

uses
  FastMM4 in 'Libs\FastMM\FastMM4.pas',
  FastMM4Messages in 'Libs\FastMM\FastMM4Messages.pas',
  SysUtils,

{$IFDEF UseCondensedHeader}
  SCS_Telemetry_Condensed                   in '..\..\..\..\Condensed API Headers\SCS_Telemetry_Condensed.pas',
{$ELSE}
  scssdk                                    in '..\..\..\..\Telemetry API Headers\scssdk.pas',
  scssdk_value                              in '..\..\..\..\Telemetry API Headers\scssdk_value.pas',
  scssdk_telemetry                          in '..\..\..\..\Telemetry API Headers\scssdk_telemetry.pas',
  scssdk_telemetry_event                    in '..\..\..\..\Telemetry API Headers\scssdk_telemetry_event.pas',
  scssdk_telemetry_channel                  in '..\..\..\..\Telemetry API Headers\scssdk_telemetry_channel.pas',
  scssdk_telemetry_common_configs           in '..\..\..\..\Telemetry API Headers\common\scssdk_telemetry_common_configs.pas',
  scssdk_telemetry_common_channels          in '..\..\..\..\Telemetry API Headers\common\scssdk_telemetry_common_channels.pas',
  scssdk_telemetry_trailer_common_channels  in '..\..\..\..\Telemetry API Headers\common\scssdk_telemetry_trailer_common_channels.pas',
  scssdk_telemetry_truck_common_channels    in '..\..\..\..\Telemetry API Headers\common\scssdk_telemetry_truck_common_channels.pas',
  scssdk_eut2                               in '..\..\..\..\Telemetry API Headers\eurotrucks2\scssdk_eut2.pas',
  scssdk_telemetry_eut2                     in '..\..\..\..\Telemetry API Headers\eurotrucks2\scssdk_telemetry_eut2.pas',
{$ENDIF}

  CRC32           in '..\..\..\Source\Libs\CRC32.pas',
  MD5             in '..\..\..\Source\Libs\MD5.pas',
{$IFDEF MulticastEvents}
  MulticastEvent  in '..\..\..\Source\Libs\MulticastEvent.pas',
{$ENDIF}
  SimpleLog       in '..\..\..\Source\Libs\SimpleLog.pas',

  TelemetryCommon           in '..\..\..\Source\TelemetryCommon.pas',
  TelemetryIDs              in '..\..\..\Source\TelemetryIDs.pas',
  TelemetryConversions      in '..\..\..\Source\TelemetryConversions.pas',
  TelemetryStrings          in '..\..\..\Source\TelemetryStrings.pas',
  TelemetryLists            in '..\..\..\Source\TelemetryLists.pas',
  TelemetryStreaming        in '..\..\..\Source\TelemetryStreaming.pas',
  TelemetryVersionObjects   in '..\..\..\Source\TelemetryVersionObjects.pas',
  TelemetryInfoProvider     in '..\..\..\Source\TelemetryInfoProvider.pas',
  TelemetryRecipient        in '..\..\..\Source\TelemetryRecipient.pas',
  TelemetryRecipientBinder  in '..\..\..\Source\TelemetryRecipientBinder.pas',
  
  TelemetryLogText          in '..\..\..\Source\Log\TelemetryLogText.pas',
  TelemetryLogBinary        in '..\..\..\Source\Log\TelemetryLogBinary.pas',
  TelemetryLogBinaryParser  in '..\..\..\Source\Log\TelemetryLogBinaryParser.pas',
  
  TelemetryNetCommon in '..\..\..\Source\NET\TelemetryNetCommon.pas',
  TelemetryNetHashing in '..\..\..\Source\NET\TelemetryNetHashing.pas',
  TelemetryNetLists in '..\..\..\Source\NET\TelemetryNetLists.pas',
  TelemetryNetIncomingStream in '..\..\..\Source\NET\TelemetryNetIncomingStream.pas',
  TelemetryNetCircularBuffers in '..\..\..\Source\NET\TelemetryNetCircularBuffers.pas',
  TelemetryNetSockets in '..\..\..\Source\NET\TelemetryNetSockets.pas',  
  TelemetryNetPackets in '..\..\..\Source\NET\TelemetryNetPackets.pas',
  TelemetryNetPacketsBuilding in '..\..\..\Source\NET\TelemetryNetPacketsBuilding.pas',
  TelemetryNetPacketsResolving in '..\..\..\Source\NET\TelemetryNetPacketsResolving.pas',
  TelemetryNetServer in '..\..\..\Source\NET\TelemetryNetServer.pas';

var
  Server:       TTelemetryNetServer = nil;
  TextLogger:   TTelemetryLogText = nil;
  BinaryLogger: TTelemetryLogBinaryFile = nil;

{$R *.res}

{=== Library exported routines ================================================}

Function TelemetryLibraryInit(version: scs_u32_t; params: p_scs_telemetry_init_params_t): scs_result_t; stdcall;
begin
If not Assigned(TextLogger) then TextLogger := TTelemetryLogText.Create;
If not TTelemetryRecipient.SupportsTelemetryAndGameVersion(
  Version,params^.common.game_id,params^.common.game_version) then
  begin
    Result := SCS_RESULT_unsupported;
    TextLogger.AddLog('Version not supported (' + SCSGetVersionAsString(version) + ' ' +
                      APIStringToTelemetryString(params^.common.game_id) + ' ' +
                      SCSGetVersionAsString(params^.common.game_version) + ')');
  end
else
  begin
    TextLogger.Logger.AddHeader;
    TextLogger.AddLog('Telemetry version: ' + SCSGetVersionAsString(version));
    TextLogger.AddLog('Game: ' + APIStringToTelemetryString(params^.common.game_name) + ' (' +
                      APIStringToTelemetryString(params^.common.game_id) + ' ' +
                      SCSGetVersionAsString(params^.common.game_version) + ')');
    TextLogger.AddLog('Creating server and recipient..');
    Server := TTelemetryNetServer.Create(TTelemetryRecipient.Create(version,params^));
    Server.ActiveMode := False;
    Server.TelemetryRecipient.Log('== Server running ==');
    Server.TelemetryRecipient.StoreChannelsValues := True;
    Server.TelemetryRecipient.ManageIndexedChannels := True;
    TextLogger.Recipient := Server.TelemetryRecipient;
    TextLogger.AssignHandlers;
    If not Assigned(BinaryLogger) then
      BinaryLogger := TTelemetryLogBinaryFile.Create(Server.TelemetryRecipient);
    BinaryLogger.SaveItemIDOnly := True;
    Result := SCS_RESULT_ok;
  end;
end;

procedure TelemetryLibraryFinal;
var
  FileName: String;
begin
FileName := BinaryLogger.FileName;
FreeAndNil(BinaryLogger);
with TTelemetryLogBinaryToTextConverter.Create(filename) do
  try
    Convert;
  finally
    Free;
  end;
FreeAndNil(TextLogger);
Server.TelemetryRecipient.Free;
end;

exports
  TelemetryLibraryInit name 'scs_telemetry_init',
  TelemetryLibraryFinal name 'scs_telemetry_shutdown';

begin
end.

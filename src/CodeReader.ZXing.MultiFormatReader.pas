{
  * Copyright 2007 ZXing authors
  *
  * LICENSEd under the Apache LICENSE, Version 2.0 (the "LICENSE");
  * you may not use this file except in compliance with the LICENSE.
  * You may obtain a copy of the LICENSE at
  *
  *      http://www.apache.org/LICENSEs/LICENSE-2.0
  *
  * Unless required by applicable law or agreed to in writing, software
  * distributed under the LICENSE is distributed on an "AS IS" BASIS,
  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  * See the LICENSE for the specific language governing permissions and
  * limitations under the LICENSE.

  * Original Authors: Sean Owen and dswitkin@google.com (Daniel Switkin)
  * Ported from ZXING Java Source: www.Redivivus.in (suraj.supekar@redivivus.in)
  * Delphi Implementation by E. Spelt and K. Gossens
}

unit CodeReader.ZXing.MultiFormatReader;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.classes,
  System.RegularExpressions,
  FMX.Types,
  CodeReader.ZXing.ReadResult,
  CodeReader.ZXing.Reader,
  CodeReader.ZXing.DecodeHintType,
  CodeReader.ZXing.BinaryBitmap,
  CodeReader.ZXing.BarcodeFormat,
  CodeReader.ZXing.ResultPoint,

  // 1D Barcodes
  CodeReader.ZXing.OneD.OneDReader,
  CodeReader.ZXing.OneD.Code128Reader,
  CodeReader.ZXing.OneD.Code93Reader,
  CodeReader.ZXing.OneD.ITFReader,
  CodeReader.ZXing.OneD.EAN13Reader,
  CodeReader.ZXing.OneD.EAN8Reader,
  CodeReader.ZXing.OneD.UPCAReader,
  CodeReader.ZXing.OneD.UPCEReader,
  CodeReader.ZXing.OneD.Code39Reader,

  // 2D Codes
  CodeReader.ZXing.QrCode.QRCodeReader,
  CodeReader.ZXing.Datamatrix.DataMatrixReader;

/// <summary>
/// MultiFormatReader is a convenience class and the main entry point into the library for most uses.
/// By default it attempts to decode all barcode formats that the library supports. Optionally, you
/// can provide a hints object to request different behavior, for example only decoding QR codes.
/// </summary>
/// <author>Sean Owen</author>
/// <author>dswitkin@google.com (Daniel Switkin)</author>
/// <author>www.Redivivus.in (suraj.supekar@redivivus.in) - Ported from ZXING Java Source</author>
type

  TMultiFormatReader = class(TInterfacedObject, IReader)
  private

    FHints: TDictionary<TDecodeHintType, TObject>;
    readers: TList<IReader>;
    FEnableQRCode: Boolean;
    FRead       : TReadResult;

    function DecodeInternal(image: TBinaryBitmap): TReadResult;
    procedure Set_Hints(const Value: TDictionary<TDecodeHintType, TObject>);
    function Get_Hints: TDictionary<TDecodeHintType, TObject>;

    /// <summary> This version of decode honors the intent of Reader.decode(BinaryBitmap) in that it
    /// passes null as a hint to the decoders. However, that makes it inefficient to call repeatedly.
    /// Use setHints() followed by decodeWithState() for continuous scan applications.
    ///
    /// </summary>
    /// <param name="image">The pixel data to decode
    /// </param>
    /// <returns> The contents of the image
    /// </returns>
    /// <throws>  ReaderException Any errors which occurred </throws>
  public
    function decode(const image: TBinaryBitmap): TReadResult; overload;
    function decode(const image: TBinaryBitmap; WithHints: Boolean) : TReadResult; overload;
    /// <summary> Decode an image using the hints provided. Does not honor existing state.
    ///
    /// </summary>
    /// <param name="image">The pixel data to decode
    /// </param>
    /// <param name="hints">The hints to use, clearing the previous state.
    /// </param>
    /// <returns> The contents of the image
    /// </returns>
    /// <throws>  ReaderException Any errors which occurred </throws>
    function decode(const image: TBinaryBitmap;
      hints: TDictionary<TDecodeHintType, TObject>): TReadResult; overload;

    /// <summary> Decode an image using the state set up by calling setHints() previously. Continuous scan
    /// clients will get a <b>large</b> speed increase by using this instead of decode().
    ///
    /// </summary>
    /// <param name="image">The pixel data to decode
    /// </param>
    /// <returns> The contents of the image
    /// </returns>
    /// <throws>  ReaderException Any errors which occurred </throws>
    function DecodeWithState(image: TBinaryBitmap): TReadResult;
    destructor Destroy; override;

    /// <summary> This method adds state to the MultiFormatReader. By setting the hints once, subsequent calls
    /// to decodeWithState(image) can reuse the same set of readers without reallocating memory. This
    /// is important for performance in continuous scan clients.
    ///
    /// </summary>
    /// <param name="hints">The set of hints to use for subsequent calls to decode(image)
    /// </param>
    property hints: TDictionary<TDecodeHintType, TObject> read Get_Hints
      write Set_Hints;

    procedure Reset;
    procedure FreeReaders();

    Property EnableQRCode : Boolean Read FEnableQRCode Write FEnableQRCode;

  end;

implementation

function TMultiFormatReader.decode(const image: TBinaryBitmap): TReadResult;
begin
hints := nil;
result := DecodeInternal(image)
end;

function TMultiFormatReader.decode(const image: TBinaryBitmap; WithHints: Boolean): TReadResult;
begin
result := DecodeInternal(image)
end;

function TMultiFormatReader.decode(const image: TBinaryBitmap; hints: TDictionary<TDecodeHintType, TObject>): TReadResult;
begin
FHints := hints;
result := DecodeInternal(image)
end;

function TMultiFormatReader.DecodeWithState(image: TBinaryBitmap): TReadResult;
begin
  // Make sure to set up the default state so we don't crash
  if readers = nil then
  begin
    hints := nil
  end;

  result := DecodeInternal(image);

end;

destructor TMultiFormatReader.Destroy;
begin
  FreeReaders;
  inherited;
end;

procedure TMultiFormatReader.FreeReaders;
begin
  if readers <> nil then
    readers.Clear();

  readers.Free;
  readers := nil;
end;

function TMultiFormatReader.Get_Hints: TDictionary<TDecodeHintType, TObject>;
begin
  result := FHints;
end;

procedure TMultiFormatReader.Set_Hints(const Value: TDictionary<TDecodeHintType, TObject>);
var
   useCode39CheckDigit,
   useCode39ExtendedMode: Boolean;
   formats: TList<TBarcodeFormat>;
begin
FHints := Value;
// tryHarder := (Value <> nil) and
// (Value.ContainsKey(CodeReader.ZXing.DecodeHintType.TRY_HARDER));

if ((Value = nil) or (not Value.ContainsKey(CodeReader.ZXing.DecodeHintType.POSSIBLE_FORMATS))) then
   begin
   formats := nil;
   end
else
   begin
   formats := Value[CodeReader.ZXing.DecodeHintType.POSSIBLE_FORMATS] as TList<TBarcodeFormat>
   end;

  // add readers from the hints
readers := TList<IReader>.Create;
if formats <> nil then
   begin
   // 1D readers
   if (formats.Contains(TBarcodeFormat.CODE_128))    then readers.Add(TCode128Reader.Create());
   if (formats.Contains(TBarcodeFormat.CODE_93))     then readers.Add(TCode93Reader.Create());
   if (formats.Contains(TBarcodeFormat.ITF))         then readers.Add(TITFReader.Create());
   // 2D readers
   if (formats.Contains(TBarcodeFormat.QR_CODE))     then readers.Add(TQRCodeReader.Create());
   if (formats.Contains(TBarcodeFormat.DATA_MATRIX)) then readers.Add(TDataMatrixReader.Create);
   if (formats.Contains(TBarcodeFormat.EAN_13))      then readers.Add(TEAN13Reader.Create());
   if (formats.Contains(TBarcodeFormat.EAN_8))       then readers.Add(TEAN8Reader.Create());
   if (formats.Contains(TBarcodeFormat.UPC_A))       then readers.Add(TUPCAReader.Create());
   if (formats.Contains(TBarcodeFormat.UPC_E))       then readers.Add(TUPCEReader.Create());
   if (formats.Contains(TBarcodeFormat.CODE_39))     then
       begin
       useCode39CheckDigit   := hints.ContainsKey(TDecodeHintType.ASSUME_CODE_39_CHECK_DIGIT) and hints.ContainsKey(TDecodeHintType.ASSUME_CODE_39_CHECK_DIGIT);
       useCode39ExtendedMode := hints.ContainsKey(TDecodeHintType.USE_CODE_39_EXTENDED_MODE)  and hints.ContainsKey(TDecodeHintType.USE_CODE_39_EXTENDED_MODE);
       readers.Add(TCode39Reader.Create(useCode39CheckDigit, useCode39ExtendedMode));
       end;
   end;

if (readers.Count = 0) then // must be auto, add them all
    begin
    // 1D readers
    readers.Add(TCode128Reader.Create());
    readers.Add(TUPCAReader   .Create());
    readers.Add(TUPCEReader   .Create());
    readers.Add(TEAN13Reader  .Create());
    readers.Add(TEAN8Reader   .Create());
    readers.Add(TCode93Reader .Create());
    readers.Add(TITFReader    .Create());
    useCode39CheckDigit   := hints.ContainsKey(TDecodeHintType.ASSUME_CODE_39_CHECK_DIGIT) and hints.ContainsKey(TDecodeHintType.ASSUME_CODE_39_CHECK_DIGIT);
    useCode39ExtendedMode := hints.ContainsKey(TDecodeHintType.USE_CODE_39_EXTENDED_MODE)  and hints.ContainsKey(TDecodeHintType.USE_CODE_39_EXTENDED_MODE);
    readers.Add(TCode39Reader.Create(useCode39CheckDigit, useCode39ExtendedMode));
     // 2D readers
    readers.Add(TQRCodeReader.Create());
    readers.Add(TDataMatrixReader.Create)
    end;
end;

procedure TMultiFormatReader.Reset;
var
   Reader: IReader;
begin
if readers <> nil then
   begin
   for Reader in readers do Reader.Reset();
   end
end;

function TMultiFormatReader.DecodeInternal(image: TBinaryBitmap): TReadResult;
var
   rpCallBack : TResultPointCallback;
   i          : integer;
   Reader     : IReader;
   Scan       : Boolean;
begin
result := nil;
if (readers = nil) then Exit;
rpCallBack := nil;
if ((FHints <> nil) and
   (FHints.ContainsKey(CodeReader.ZXing.DecodeHintType.NEED_RESULT_POINT_CALLBACK))) then
    begin
    // rpCallBack := FHints[DecodeHintType.NEED_RESULT_POINT_CALLBACK]
    // as TResultPointCallback(nil);
    end;
for i := 0 to readers.Count - 1 do
    begin
    Scan   := True;
    Reader := readers[i];
    if (Reader Is TQRCodeReader) Or (Reader Is TDataMatrixReader) then
       Scan := FEnableQRCode;
    if Scan Then
       Begin
       Reader.Reset();
       Result := Reader.decode(image, FHints);
       if Result <> nil then
          begin

          // found a barcode, pushing the successful reader up front
          // I assume that the same type of barcode is read multiple times
          // so the reordering of the readers list should speed up the next reading
          // a little bit

          readers.Delete(i);
          readers.Insert(0, Reader);
          Exit;
          end;
       End;
    // if rpCallBack <> nil then
    // rpCallBack(nil)
    end;
Result := FRead;
end;

end.

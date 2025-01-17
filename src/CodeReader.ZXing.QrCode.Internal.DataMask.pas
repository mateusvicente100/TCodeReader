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

  * Original Author: Sean Owen
  * Ported from ZXING Java Source: www.Redivivus.in (suraj.supekar@redivivus.in)
  * Delphi Implementation by E. Spelt and K. Gossens
}

unit CodeReader.ZXing.QrCode.Internal.DataMask;

interface

uses 
  SysUtils, 
  CodeReader.ZXing.Common.BitMatrix, 
  CodeReader.ZXing.Common.Detector.MathUtils;

type
  /// <summary> <p>Encapsulates data masks for the data bits in a QR code, per ISO 18004:2006 6.8. Implementations
  /// of this class can un-mask a raw BitMatrix. For simplicity, they will unmask the entire BitMatrix,
  /// including areas used for finder patterns, timing patterns, etc. These areas should be unused
  /// after the point they are unmasked anyway.</p>
  ///
  /// <p>Note that the diagram in section 6.8.1 is misleading since it indicates that i is column position
  /// and j is row position. In fact, as the text says, i is row position and j is column position.</p>
  /// </summary>
  TDataMask = class abstract
  private
    /// <summary> See ISO 18004:2006 6.8.1</summary>
    class var DATA_MASKS: TArray<TDataMask>;

    class procedure InitializeClass;
    class procedure FinalizeClass;

    function isMasked(const i, j: Integer): Boolean; virtual; abstract;
  public
    /// <param name="reference">a value between 0 and 7 indicating one of the eight possible
    /// data mask patterns a QR Code may use
    /// </param>
    /// <returns> {@link DataMask} encapsulating the data mask pattern
    /// </returns>
    class function forReference(const reference: Integer): TDataMask; static;

    /// <summary> <p>Implementations of this method reverse the data masking process applied to a QR Code and
    /// make its bits ready to read.</p>
    /// </summary>
    /// <param name="bits">representation of QR Code bits
    /// </param>
    /// <param name="dimension">dimension of QR Code, represented by bits, being unmasked
    /// </param>
    procedure unmaskBitMatrix(const bits: TBitMatrix; const dimension: Integer);
  end;

  /// <summary> 000: mask bits for which (x + y) mod 2 == 0</summary>
  TDataMask000 = class(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 001: mask bits for which x mod 2 == 0</summary>
  TDataMask001 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 010: mask bits for which y mod 3 == 0</summary>
  TDataMask010 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 011: mask bits for which (x + y) mod 3 == 0</summary>
  TDataMask011 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 100: mask bits for which (x/2 + y/3) mod 2 == 0</summary>
  TDataMask100 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 101: mask bits for which xy mod 2 + xy mod 3 == 0</summary>
  TDataMask101 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 110: mask bits for which (xy mod 2 + xy mod 3) mod 2 == 0</summary>
  TDataMask110 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

  /// <summary> 111: mask bits for which ((x+y)mod 2 + xy mod 3) mod 2 == 0</summary>
  TDataMask111 = class sealed(TDataMask)
  private
    function isMasked(const i, j: Integer): Boolean; override;
  end;

implementation

{ TDataMask }

class procedure TDataMask.InitializeClass;
begin
  TDataMask.DATA_MASKS := TArray<TDataMask>.Create(TDataMask000.Create,
                                                   TDataMask001.Create,
                                                   TDataMask010.Create,
                                                   TDataMask011.Create,
                                                   TDataMask100.Create,
                                                   TDataMask101.Create,
                                                   TDataMask110.Create,
                                                   TDataMask111.Create);
end;

class procedure TDataMask.FinalizeClass;
var
  dam: TDataMask;
begin
  for dam in TDataMask.DATA_MASKS do
    dam.Free;
  DATA_MASKS := nil;
end;

class function TDataMask.forReference(const reference: Integer): TDataMask;
begin
  if ((reference < 0) or (reference > 7))
  then
     raise EArgumentException.Create('Invalid arguments');

  Result := TDataMask.DATA_MASKS[reference];
end;

procedure TDataMask.unmaskBitMatrix(const bits: TBitMatrix;
  const dimension: Integer);
var
  i, j: Integer;
begin
  for i := 0 to Pred(dimension) do
    for j := 0 to Pred(dimension) do
      if (self.isMasked(i, j))
      then
         bits.flip(j, i);
end;

{ TDataMask000 }

function TDataMask000.isMasked(const i, j: Integer): Boolean;
begin
  Result := ((i + j) and $01) = 0;
end;

{ TDataMask001 }

function TDataMask001.isMasked(const i, j: Integer): Boolean;
begin
  Result := (i and $01) = 0;
end;

{ TDataMask010 }

function TDataMask010.isMasked(const i, j: Integer): Boolean;
begin
  Result := (j mod 3) = 0;
end;

{ TDataMask011 }

function TDataMask011.isMasked(const i, j: Integer): Boolean;
begin
  Result := (((i + j) mod 3) = 0)
end;

{ TDataMask100 }

function TDataMask100.isMasked(const i, j: Integer): Boolean;
begin
   Result := (( TMathUtils.Asr(UInt32(i),1) + (j div 3)) and $01) = 0;
end;

{ TDataMask101 }

function TDataMask101.isMasked(const i, j: Integer): Boolean;
var
  temp: Integer;
begin
  temp := (i * j);
  Result := ((temp and $01) + (temp mod 3)) = 0;
end;

{ TDataMask110 }

function TDataMask110.isMasked(const i, j: Integer): Boolean;
var
  temp: Integer;
begin
  temp := (i * j);
  Result := (((temp and $01) + (temp mod 3)) and 1) = 0;
end;

{ TDataMask111 }

function TDataMask111.isMasked(const i, j: Integer): Boolean;
begin
  Result := ((((i + j) and $01) + ((i * j) mod 3)) and $01) = 0;
end;

initialization
  TDataMask.InitializeClass;
finalization
  TDataMask.FinalizeClass;
end.

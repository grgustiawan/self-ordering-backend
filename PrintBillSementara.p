ROUTINE-LEVEL ON ERROR UNDO, THROW.
DEFINE INPUT PARAMETER iCartID  AS INTEGER                      NO-UNDO.
DEFINE INPUT PARAMETER iPesanan AS CHARACTER                    NO-UNDO.
DEFINE INPUT PARAMETER iMeja    AS CHARACTER                    NO-UNDO.
DEFINE INPUT PARAMETER iNotrans AS INTEGER                      NO-UNDO.
DEFINE INPUT PARAMETER iTanggal AS CHARACTER                    NO-UNDO.
DEFINE INPUT PARAMETER iKharga  AS CHARACTER                    NO-UNDO.

DEFINE VARIABLE cTotal          AS INTEGER                      NO-UNDO.
DEFINE VARIABLE cQuantity       AS INTEGER     INITIAL 0        NO-UNDO.

OUTPUT TO "D:\temp\bill.txt".
PUT UNFORMATTED "@a" SKIP.
PUT UNFORMATTED "!XBILL SEMENTARA" SKIP.
PUT UNFORMATTED "@" SKIP (1).

PUT UNFORMATTED "Tanggal  : " + STRING(TODAY, "99/99/9999") + " - " + STRING(TIME, "HH:MM") SKIP.
PUT UNFORMATTED "No. Meja : " iMeja + " " + iKharga + " " + iPesanan SKIP  (1).

PUT UNFORMATTED "@======================================" SKIP.
  
FOR EACH trdtl WHERE trdtl.cartid = iCartID AND trdtl.pesanan = iPesanan 
                 AND trdtl.meja = iMeja AND trdtl.notrans = iNotrans 
                 AND trdtl.tgl = iTanggal NO-LOCK:
    FIND FIRST btndtl1 WHERE btndtl1.kode = trdtl.kode NO-LOCK NO-ERROR.
    IF AVAIL btndtl1 THEN
    DO:
        cQuantity = cQuantity + trdtl.qorder.
        cTotal = trdtl.qorder * trdtl.harga.
        PUT UNFORMATTED btndtl1.nama SKIP.
        PUT UNFORMATTED STRING(INTEGER(trdtl.qorder)) + "  X" AT 8.
        PUT trdtl.harga AT 13.
        PUT cTotal AT 30 SKIP.
    END.
END.

PUT UNFORMATTED "@              ========================" SKIP.
PUT UNFORMATTED " ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹" SKIP.
PUT UNFORMATTED "! ›MINTALAH BILL TETAP. JIKA ANDA TIDAKﬁ" SKIP.
PUT UNFORMATTED "! ›MENDAPATKAN BILL TETAP, MAKAN GRATISﬁ" SKIP.
PUT UNFORMATTED "! ›  STRUK INI ADALAH BILL SEMENTARA   ﬁ" SKIP.
PUT UNFORMATTED " ﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂﬂ" SKIP.
PUT UNFORMATTED "@" SKIP.

FIND FIRST trhdr WHERE trhdr.tgl = iTanggal AND trhdr.cartid = iCartID 
                   AND trhdr.pesanan = iPesanan AND trhdr.meja = iMeja 
                   AND trhdr.notrans = iNotrans NO-LOCK NO-ERROR.
IF AVAIL trhdr THEN DO:
    PUT UNFORMATTED "Jumlah Item   :         " + STRING(cQuantity) SKIP.
    PUT UNFORMATTED "Sub Total     :" AT 0.
    PUT trhdr.TOTAL AT 26 SKIP.
    PUT UNFORMATTED "Pajak Resto   :" AT 0.
    PUT trhdr.ttax  AT 26 SKIP.
    PUT UNFORMATTED "Grand Total   :" AT 0.
    PUT trhdr.grand AT 26 SKIP(1).
END.

PUT UNFORMATTED "Terima Kasih" AT 15 SKIP.
PUT UNFORMATTED "Atas Kunjungan Anda" AT 12 SKIP(1).
PUT UNFORMATTED "No Service Charge" AT 13 SKIP(7).
PUT UNFORMATTED "Vp0dñ@" SKIP.
OUTPUT CLOSE.
 
DO:
    MESSAGE "BEGIN PRINTING".
    FIND FIRST tprn WHERE tprn.pcode = "ESTRUK" NO-LOCK NO-ERROR.
    IF AVAIL tprn THEN DO:
        OS-COMMAND NO-WAIT VALUE("print /d:" + STRING(tprn.pdevice) + " D:\temp\bill.txt").
        OS-DELETE VALUE("D:\temp\bill.txt").
    END.
    MESSAGE "END PRINTING".
END.

CATCH mySysError AS Progress.Lang.SysError:
   MESSAGE "Error message : " + mySysError:GetMessage(1) SKIP.
END CATCH.

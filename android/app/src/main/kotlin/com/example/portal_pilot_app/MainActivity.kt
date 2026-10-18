package com.example.portal_pilot_app

import android.app.Activity
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

class MainActivity : FlutterActivity() {

    private val channelName = "portal_pilot/nfc_card"
    private val updateChannelName = "portal_pilot/app_update"
    private var nfcAdapter: android.nfc.NfcAdapter? = null
    private var pendingResult: MethodChannel.Result? = null
    private var updateResult: Result? = null
    private var downloadReceiver: BroadcastReceiver? = null
    private var downloadId: Long = -1

    // ═══ AUTO-ACTUALIZACIÓN APK ═══
    private fun downloadAndInstallApk(apkUrl: String, versionName: String, versionCode: Int, result: Result) {
        updateResult = result

        // Verificar permiso de instalación (Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val packageInstaller = packageManager
            val canInstall = packageInstaller.canRequestPackageInstalls()
            if (!canInstall) {
                result.error("PERMISO_DENEGADO", "La app no tiene permiso para instalar paquetes. Ve a Ajustes > Apps > Acceso especial > Instalar apps desconocidas.", null)
                updateResult = null
                return
            }
        }

        // Crear archivo destino en directorio privado de la app
        val apkFile = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "PortalPilot_v${versionName}_${versionCode}.apk")
        apkFile.parentFile?.mkdirs()

        // Configurar descarga con DownloadManager
        val request = DownloadManager.Request(Uri.parse(apkUrl))
            .setTitle("Portal Pilot v$versionName")
            .setDescription("Descargando actualización...")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationUri(Uri.fromFile(apkFile))
            .setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI or DownloadManager.Request.NETWORK_MOBILE)
            .setAllowedOverRoaming(false)
            .setRequiresCharging(false)

        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        downloadId = downloadManager.enqueue(request)

        // Registrar receiver para cuando termine la descarga
        downloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val action = intent.action
                if (action == DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
                    val query = DownloadManager.Query().setFilterById(downloadId)
                    val cursor = downloadManager.query(query)
                    if (cursor.moveToFirst()) {
                        val columnIndex = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
                        val status = cursor.getInt(columnIndex)
                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            // Descarga completada, iniciar instalación
                            installApk(apkFile)
                        } else if (status == DownloadManager.STATUS_FAILED) {
                            val reasonIndex = cursor.getColumnIndex(DownloadManager.COLUMN_REASON)
                            val reason = cursor.getInt(reasonIndex)
                            updateResult?.error("DESCARGA_FALLIDA", "Error descargando APK (código: $reason)", null)
                            updateResult = null
                        }
                    }
                    cursor.close()
                    unregisterDownloadReceiver()
                }
            }
        }

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver!!, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(downloadReceiver!!, filter)
        }

        result.success("Descarga iniciada")
    }

    private fun installApk(apkFile: File) {
        if (!apkFile.exists()) {
            updateResult?.error("ARCHIVO_NO_EXISTE", "El APK descargado no se encuentra", null)
            updateResult = null
            return
        }

        val apkUri: Uri
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            apkUri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                apkFile
            )
        } else {
            apkUri = Uri.fromFile(apkFile)
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }

        try {
            // Para Android 12+, usar startActivityForResult no está disponible desde FlutterActivity
            // Usamos un intent directo que el usuario debe confirmar
            startActivity(intent)
            updateResult?.success("Instalador abierto - confirma la instalación")
        } catch (e: Exception) {
            updateResult?.error("ERROR_INSTALACION", "No se pudo abrir el instalador: ${e.message}", null)
        }
        updateResult = null
    }

    private fun unregisterDownloadReceiver() {
        downloadReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
            downloadReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterDownloadReceiver()
        super.onDestroy()
    }

    // ═══ NFC EXISTENTE ═══
    private val readerFlags: Int = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NO_PLATFORM_SOUNDS or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK

    private val readerModeExtras = Bundle().apply {
        putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 200)
    }

    private val readerCallback = NfcAdapter.ReaderCallback { tag ->
        runOnUiThread {
            val detection = detectarTag(tag)
            pendingResult?.success(detection)
            pendingResult = null
            detenerDeteccion()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcAdapter = try {
            android.nfc.NfcAdapter.getDefaultAdapter(this)
        } catch (e: Exception) {
            null
        }

        // Canal NFC existente
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nfc_ready" -> {
                        val ok = nfcAdapter != null && nfcAdapter!!.isEnabled
                        result.success(ok)
                    }
                    "nfc_supported" -> result.success(nfcAdapter != null)
                    "detect" -> {
                        if (nfcAdapter == null) {
                            result.error("NFC_NO_DISPONIBLE", "Este dispositivo no tiene NFC.", null)
                        } else if (!nfcAdapter!!.isEnabled) {
                            result.error("NFC_APAGADO", "Activa NFC en Ajustes para leer la tarjeta.", null)
                        } else if (pendingResult != null) {
                            result.error("OCUPADO", "Ya hay una lectura de tarjeta en curso.", null)
                        } else {
                            pendingResult = result
                            iniciarDeteccion()
                        }
                    }
                    "stop" -> {
                        detenerDeteccion()
                        pendingResult?.error("CANCELADO", "Lectura cancelada.", null)
                        pendingResult = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal para auto-actualización
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "downloadAndInstall" -> {
                        val apkUrl = call.argument<String>("apkUrl") ?: return@setMethodCallHandler result.error("URL_INVALIDA", "URL del APK requerida", null)
                        val versionName = call.argument<String>("versionName") ?: "desconocida"
                        val versionCode = call.argument<Int>("versionCode") ?: 0
                        downloadAndInstallApk(apkUrl, versionName, versionCode, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun iniciarDeteccion() {
        try {
            nfcAdapter?.enableReaderMode(this, readerCallback, readerFlags, readerModeExtras)
        } catch (e: Exception) {
            pendingResult?.error("NFC_ERROR", "No se pudo iniciar el lector NFC: ${e.message}", null)
            pendingResult = null
        }
    }

    private fun detenerDeteccion() {
        try {
            nfcAdapter?.disableReaderMode(this)
        } catch (_: Exception) {}
    }

    private fun detectarTag(tag: Tag): Map<String, Any?> {
        val uid = tag.id?.toHex() ?: ""
        var marca = "DESCONOCIDA"
        var ultimos4: String? = null
        var tecnologia = "NFC"
        val aids = mutableListOf<String>()
        var ats: String? = null
        var isodepOk = false

        try {
            val isodep = IsoDep.get(tag)
            if (isodep != null) {
                isodep.connect()
                isodepOk = true
                try {
                    isodep.historicalBytes?.let { hb -> ats = hb.toHex() }
                } catch (_: Exception) {}

                // 1) SELECT PPSE (directorio '2PAY.SYS.DDF01'): primer paso de un POS real
                val selectPpse = byteArrayOf(
                    0x00, 0xA4.toByte(), 0x04, 0x00, 0x0E
                ) + "2PAY.SYS.DDF01".toByteArray() + byteArrayOf(0x00)
                val ppse = transceive(isodep, selectPpse)

                // 2) READ RECORD del SFI indicado en el FCI para obtener los AIDs
                val sfi = buscarSfi(ppse)
                if (sfi != null) {
                    for (rec in 1..8) {
                        val cmd = byteArrayOf(0x00, 0xB2.toByte(), rec.toByte(), (0x80 or sfi).toByte(), 0x00)
                        val resp = transceive(isodep, cmd)
                        if (resp == null) break
                        if (resp.isNotEmpty() && resp[0] == 0x70.toByte()) {
                            buscarAid(resp)?.let { aid ->
                                val hex = aid.toHex()
                                if (!aids.contains(hex)) {
                                    aids.add(hex)
                                    if (marca == "DESCONOCIDA") {
                                        marca = marcarPorAid(hex)
                                    }
                                }
                            }
                        } else if (resp.isNotEmpty() && esError(response = resp)) {
                            break
                        }
                    }
                }

                // 3) Best-effort: SELECT AID y escaneo de registros en busca del PAN
                val pan = intentarLeerPan(isodep, aids)
                if (pan != null) ultimos4 = pan

                isodep.close()
            }
        } catch (_: Exception) {}

        if (isodepOk) tecnologia = "ISO-DEP (EMV)"

        return mapOf(
            "uid" to uid,
            "marca" to marca,
            "ultimos4" to ultimos4,
            "tecnologia" to tecnologia,
            "aids" to aids,
            "ats" to ats,
        )
    }

    /** Envía APDU y devuelve bytes de respuesta útil o null en errores. */
    private fun transceive(isodep: IsoDep, cmd: ByteArray): ByteArray? {
        return try {
            val r = isodep.transceive(cmd)
            if (r.isNotEmpty() && esError(response = r)) null else clamp(r)
        } catch (_: Exception) {
            null
        }
    }

    /** Devuelve la respuesta sin SW1/SW2. */
    private fun clamp(r: ByteArray): ByteArray {
        return if (r.size >= 2) r.copyOfRange(0, r.size - 2) else r
    }

    /** 61xx / 6xxx = errores APDU (sin incluir 61.. ni 6C.. normales). */
    private fun esError(response: ByteArray): Boolean {
        if (response.size < 2) return true
        val sw = response[response.size - 2].toInt() and 0xFF
        return sw == 0x6A.toInt()
    }

    /** Busca el SFI del directorio (byte 90..: 88 01 <sfi>) en la respuesta. */
    private fun buscarSfi(data: ByteArray?): Int? {
        if (data == null) return null
        for (i in 0 until data.size - 2) {
            if (data[i] == 0x88.toByte() && data[i + 1] == 0x01.toByte()) {
                return data[i + 2].toInt() and 0x1F
            }
        }
        return 1
    }

    /** Extrae el AID de un record 70/61 del directorio. */
    private fun buscarAid(data: ByteArray): ByteArray? {
        var i = 0
        while (i < data.size - 1) {
            val tag = data[i].toInt() and 0xFF
            val len = data[i + 1].toInt() and 0xFF
            if (tag == 0x61 || tag == 0x70) {
                if (i + 2 + len < data.size || i + 2 + len == data.size) {
                    // tlv interno
                    var j = i + 2
                    while (j < data.size - 1) {
                        val b = data[j].toInt() and 0xFF
                        val l2 = data[j + 1].toInt() and 0xFF
                        if (b == 0x4F && l2 > 0 && l2 <= 16 && j + 2 + l2 <= data.size) {
                            return data.copyOfRange(j + 2, j + 2 + l2)
                        }
                        j += 2
                    }
                }
                return null
            }
            i += 2
        }
        return null
    }

    private fun marcarPorAid(hex: String): String {
        val p = hex
        return when {
            p.startsWith("A000000003") -> "VISA"
            p.startsWith("A000000004") -> "MASTERCARD"
            p.startsWith("A000000025") -> "AMEX"
            p.startsWith("A000000037") -> "DINERS"
            p.startsWith("A000000324") -> "DISCOVER"
            p.startsWith("A000000152") -> "DISCOVER"
            p.startsWith("A000000065") -> "JCB"
            p.startsWith("A000000333") -> "UNIONPAY"
            else -> "DESCONOCIDA"
        }
    }

    /** SELECT del AID principal + recorrido de SFI/records buscando un PAN (Luhn). */
    private fun intentarLeerPan(isodep: IsoDep, aids: List<String>): String? {
        if (aids.isEmpty()) return null
        // Preferir AIDs de pago (VISA/MC) antes que wallets/otros
        val aid = aids.firstOrNull {
            it.startsWith("A000000003") || it.startsWith("A000000004")
        } ?: aids.first()
        val bytes = hexToBytes(aid)
        val selectAid = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, bytes.size.toByte()) +
                bytes + byteArrayOf(0x00)
        val fci = transceive(isodep, selectAid) ?: return null

        // Determinar SFI del FCI (si el FCI define AFL lo usamos; si no, probamos SFI 1)
        var sfiActual = buscarSfi(fci)
        if (sfiActual == null || sfiActual == 1) sfiActual = 1

        for (sfi in sfiActual..sfiActual + 2) {
            for (rec in 1..4) {
                val cmd = byteArrayOf(0x00, 0xB2.toByte(), rec.toByte(), (0x80 or sfi).toByte(), 0x00)
                val resp = transceive(isodep, cmd) ?: continue
                if (resp.isEmpty()) continue
                if (resp[0] == 0x70.toByte() || resp[0] == 0x61.toByte()) {
                    val pan = luhnBuscar(String(resp, Charsets.ISO_8859_1))
                    if (pan != null) return pan
                }
            }
        }
        return null
    }

    /** Busca una secuencia de 13-19 dígitos que pase Luhn; devuelve sus últimos 4. */
    private fun luhnBuscar(texto: String): String? {
        var i = 0
        while (i < texto.length) {
            val c = texto[i]
            if (c.isDigit() && (c == '4' || c == '5' || c == '3' || c == '6')) {
                var j = i
                while (j < texto.length && texto[j].isDigit() && j - i < 19) j++
                val candidato = texto.substring(i, j)
                if (candidato.length in 13..19 && luhnValido(candidato)) {
                    return candidato.substring(candidato.length - 4)
                }
                i = j
            } else {
                i++
            }
        }
        return null
    }

    private fun luhnValido(num: String): Boolean {
        var suma = 0
        var par = false
        for (k in num.length - 1 downTo 0) {
            var d = num[k].toInt() - 48
            if (par) {
                d *= 2
                if (d > 9) d -= 9
            }
            suma += d
            par = !par
        }
        return suma % 10 == 0
    }

    private fun hexToBytes(hex: String): ByteArray {
        val out = ByteArray(hex.length / 2)
        for (i in out.indices) {
            val idx = i * 2
            out[i] = (hex.substring(idx, idx + 2).toInt(16) and 0xFF).toByte()
        }
        return out
    }

    private fun ByteArray.toHex(): String = joinToString("") { String.format("%02X", it) }
}
package com.example.voxa.ime

import android.Manifest
import android.annotation.SuppressLint
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.example.voxa.ImePrefs
import com.example.voxa.MainActivity
import com.example.voxa.R

class ChiVoiceInputMethodService : android.inputmethodservice.InputMethodService(),
    RecognitionListener {
    private lateinit var imePrefs: ImePrefs
    private lateinit var snapshot: ImePrefs.Snapshot

    private lateinit var languageButton: TextView
    private lateinit var statusText: TextView
    private lateinit var headerAction: TextView
    private lateinit var previewText: TextView
    private lateinit var micButton: TextView
    private lateinit var hintText: TextView
    private lateinit var pasteAction: TextView
    private lateinit var promptAction: TextView
    private lateinit var deleteAction: TextView
    private lateinit var doneAction: TextView
    private lateinit var waveformView: VoiceWaveformView

    private var speechRecognizer: SpeechRecognizer? = null
    private var uiState = UiState.IDLE
    private var pendingTranscript = ""
    private var elapsedSeconds = 0

    private val mainHandler = Handler(Looper.getMainLooper())
    private val timerRunnable = object : Runnable {
        override fun run() {
            if (uiState == UiState.LISTENING || uiState == UiState.PROCESSING) {
                elapsedSeconds += 1
                updateStatusText()
                mainHandler.postDelayed(this, 1000L)
            }
        }
    }

    override fun onCreateInputView(): View {
        imePrefs = ImePrefs(applicationContext)
        val rootView = LayoutInflater.from(this).inflate(
            R.layout.view_chivoice_ime,
            null,
        )
        bindViews(rootView)
        bindListeners()
        refreshSnapshot()
        renderIdle()
        return rootView
    }

    override fun onStartInputView(info: android.view.inputmethod.EditorInfo?, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        refreshSnapshot()
        if (uiState != UiState.LISTENING && uiState != UiState.PROCESSING) {
            renderIdle()
        }
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        mainHandler.removeCallbacks(timerRunnable)
        speechRecognizer?.cancel()
        waveformView.setActive(false)
        uiState = UiState.IDLE
        super.onFinishInputView(finishingInput)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(timerRunnable)
        speechRecognizer?.destroy()
        speechRecognizer = null
        super.onDestroy()
    }

    private fun bindViews(rootView: View) {
        languageButton = rootView.findViewById(R.id.imeLanguageButton)
        statusText = rootView.findViewById(R.id.imeStatusText)
        headerAction = rootView.findViewById(R.id.imeHeaderAction)
        previewText = rootView.findViewById(R.id.imePreviewText)
        micButton = rootView.findViewById(R.id.imeMicButton)
        hintText = rootView.findViewById(R.id.imeHintText)
        pasteAction = rootView.findViewById(R.id.imePasteAction)
        promptAction = rootView.findViewById(R.id.imePromptAction)
        deleteAction = rootView.findViewById(R.id.imeDeleteAction)
        doneAction = rootView.findViewById(R.id.imeDoneAction)
        waveformView = rootView.findViewById(R.id.imeWaveformView)
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun bindListeners() {
        languageButton.setOnClickListener {
            val nextLanguage = imePrefs.cycleLanguage(snapshot.languageCode)
            snapshot = snapshot.copy(languageCode = nextLanguage)
            refreshSnapshot()
            showToast("已切换为 ${imePrefs.languageLabel(nextLanguage)}")
        }

        headerAction.setOnClickListener {
            when (uiState) {
                UiState.LISTENING, UiState.PROCESSING -> cancelListening()
                UiState.PREVIEW -> {
                    pendingTranscript = ""
                    renderIdle()
                }

                UiState.IDLE -> showInputMethodPicker()
            }
        }

        micButton.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startListening()
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (uiState == UiState.LISTENING) {
                        finishListening()
                    }
                    true
                }

                MotionEvent.ACTION_CANCEL -> {
                    if (uiState == UiState.LISTENING) {
                        cancelListening()
                    }
                    true
                }

                else -> false
            }
        }

        pasteAction.setOnClickListener {
            when (uiState) {
                UiState.PREVIEW -> copyPreviewToClipboard()
                UiState.IDLE -> pasteClipboardText()
                else -> Unit
            }
        }

        promptAction.setOnClickListener {
            when (uiState) {
                UiState.PREVIEW -> renderIdle(
                    "已清空当前结果，再按住说话即可重录。",
                )

                UiState.IDLE -> launchMainApp()
                else -> Unit
            }
        }

        deleteAction.setOnClickListener {
            when (uiState) {
                UiState.PREVIEW -> trimPreviewText()
                UiState.IDLE -> currentInputConnection?.deleteSurroundingText(1, 0)
                else -> Unit
            }
        }

        doneAction.setOnClickListener {
            when (uiState) {
                UiState.PREVIEW -> commitPreviewToEditor()
                UiState.IDLE -> requestHideSelf(0)
                else -> Unit
            }
        }
    }

    private fun refreshSnapshot() {
        snapshot = imePrefs.snapshot()
        languageButton.text = imePrefs.languageLabel(snapshot.languageCode)
        applyPalette()
    }

    private fun applyPalette() {
        val primary = snapshot.primaryColor
        val secondary = snapshot.secondaryColor

        tintPill(languageButton, alpha(primary, 0.08f), primary, primary)
        tintPill(headerAction, Color.WHITE, primary, getColorCompat(R.color.ime_ink))
        tintPill(pasteAction, Color.WHITE, primary, getColorCompat(R.color.ime_ink))
        tintPill(promptAction, Color.WHITE, primary, getColorCompat(R.color.ime_ink))
        tintPill(deleteAction, Color.WHITE, primary, getColorCompat(R.color.ime_ink))
        tintPill(doneAction, alpha(primary, 0.12f), primary, primary)

        val previewDrawable = previewText.background.mutate() as GradientDrawable
        previewDrawable.setStroke(dp(1), alpha(primary, 0.20f))
        previewDrawable.setColor(getColorCompat(R.color.ime_panel))

        val micDrawable = micButton.background.mutate() as GradientDrawable
        micDrawable.setStroke(dp(if (uiState == UiState.LISTENING) 6 else 4), primary)
        micDrawable.setColor(Color.WHITE)

        waveformView.setAccentColor(
            blend(primary, secondary, 0.25f),
        )
    }

    private fun startListening() {
        if (uiState == UiState.LISTENING || uiState == UiState.PROCESSING) {
            return
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            showToast("当前设备不支持语音识别。")
            return
        }
        if (!hasMicrophonePermission()) {
            showToast("请先在主 App 中授予麦克风权限。")
            launchMainApp()
            return
        }

        prepareSpeechRecognizer()
        pendingTranscript = ""
        elapsedSeconds = 0
        uiState = UiState.LISTENING
        waveformView.setActive(true)
        mainHandler.removeCallbacks(timerRunnable)
        mainHandler.post(timerRunnable)
        renderListening()
        speechRecognizer?.startListening(buildRecognizerIntent())
    }

    private fun finishListening() {
        if (uiState != UiState.LISTENING) {
            return
        }
        uiState = UiState.PROCESSING
        renderProcessing()
        speechRecognizer?.stopListening()
    }

    private fun cancelListening() {
        speechRecognizer?.cancel()
        mainHandler.removeCallbacks(timerRunnable)
        waveformView.setActive(false)
        pendingTranscript = ""
        renderIdle("已取消当前录音。")
    }

    private fun prepareSpeechRecognizer() {
        if (speechRecognizer != null) {
            return
        }
        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).also {
            it.setRecognitionListener(this)
        }
    }

    private fun buildRecognizerIntent(): Intent {
        return Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE,
                imePrefs.recognitionLanguage(snapshot.languageCode),
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
    }

    private fun renderIdle(message: String? = null) {
        uiState = UiState.IDLE
        mainHandler.removeCallbacks(timerRunnable)
        waveformView.setActive(false)
        pendingTranscript = ""
        previewText.text = message ?: "轻声落字，按住下方说话。"
        previewText.alpha = if (message == null) 0.9f else 1f
        hintText.text = "支持实时预览，松开发送。"
        micButton.text = "按住\n说话"
        headerAction.text = "切换输入法"
        pasteAction.text = "粘贴"
        promptAction.text = "打开 App"
        deleteAction.text = "退格"
        doneAction.text = "完成"
        updateStatusText()
        setActionEnabled(true)
        applyPalette()
    }

    private fun renderListening() {
        previewText.text = "正在聆听…"
        previewText.alpha = 0.88f
        hintText.text = "保持按住，松开后会进入识别预览。"
        micButton.text = "松开\n发送"
        headerAction.text = "取消"
        pasteAction.text = "粘贴"
        promptAction.text = "打开 App"
        deleteAction.text = "退格"
        doneAction.text = "完成"
        updateStatusText()
        setActionEnabled(false)
        applyPalette()
    }

    private fun renderProcessing() {
        hintText.text = "正在整理语音，请稍候…"
        micButton.text = "识别中"
        headerAction.text = "取消"
        previewText.alpha = 0.96f
        updateStatusText()
        setActionEnabled(false)
        applyPalette()
    }

    private fun renderPreview(finalText: String) {
        pendingTranscript = finalText
        uiState = UiState.PREVIEW
        mainHandler.removeCallbacks(timerRunnable)
        waveformView.setActive(false)
        previewText.text = finalText
        previewText.alpha = 1f
        hintText.text = "可复制、删一字，或直接送入当前输入框。"
        micButton.text = "重按\n录音"
        headerAction.text = "重录"
        pasteAction.text = "复制"
        promptAction.text = "重录"
        deleteAction.text = "删一字"
        doneAction.text = "写入"
        updateStatusText()
        setActionEnabled(true)
        applyPalette()
    }

    private fun updateStatusText() {
        statusText.text = when (uiState) {
            UiState.IDLE -> "系统语音输入法"
            UiState.LISTENING -> "倾听中 · ${formatElapsed(elapsedSeconds)}"
            UiState.PROCESSING -> "整理语音中 · ${formatElapsed(elapsedSeconds)}"
            UiState.PREVIEW -> "识别完成 · ${pendingTranscript.length} 字符"
        }
    }

    private fun setActionEnabled(enabled: Boolean) {
        pasteAction.isEnabled = enabled
        promptAction.isEnabled = enabled
        deleteAction.isEnabled = enabled
        doneAction.isEnabled = enabled
        val disabledAlpha = if (enabled) 1f else 0.45f
        pasteAction.alpha = disabledAlpha
        promptAction.alpha = disabledAlpha
        deleteAction.alpha = disabledAlpha
        doneAction.alpha = disabledAlpha
    }

    private fun pasteClipboardText() {
        val clipboard =
            getSystemService(Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
        val item = clipboard?.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)
        val text = item?.coerceToText(this)?.toString()?.trim().orEmpty()
        if (text.isEmpty()) {
            showToast("剪贴板里暂时没有可粘贴的文字。")
            return
        }
        currentInputConnection?.commitText(text, 1)
    }

    private fun copyPreviewToClipboard() {
        if (pendingTranscript.isBlank()) {
            return
        }
        val clipboard =
            getSystemService(Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
        clipboard?.setPrimaryClip(
            ClipData.newPlainText("ChiVoice transcript", pendingTranscript),
        )
        showToast("文字已复制到剪贴板。")
    }

    private fun trimPreviewText() {
        if (pendingTranscript.isEmpty()) {
            return
        }
        pendingTranscript = pendingTranscript.dropLast(1)
        if (pendingTranscript.isEmpty()) {
            renderIdle("当前预览已清空。")
        } else {
            previewText.text = pendingTranscript
            updateStatusText()
        }
    }

    private fun commitPreviewToEditor() {
        val text = pendingTranscript.trim()
        if (text.isEmpty()) {
            return
        }
        currentInputConnection?.commitText(text, 1)
        requestHideSelf(0)
        showToast("已写入当前输入框。")
        pendingTranscript = ""
        renderIdle()
    }

    private fun showInputMethodPicker() {
        if (switchToNextInputMethod(false)) {
            return
        }
        val manager = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager
        manager?.showInputMethodPicker()
    }

    private fun launchMainApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(launchIntent)
    }

    private fun hasMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun normalizeTranscript(value: String, finalize: Boolean): String {
        var normalized = value.trim()
        if (normalized.isEmpty()) {
            return normalized
        }
        normalized = normalized
            .replace(Regex("\\s+([,.!?])"), "$1")
            .replace(Regex("\\s+([，。！？；：])"), "$1")
            .replace(Regex("\\s{2,}"), " ")

        val usesCjk = snapshot.languageCode.startsWith("zh") ||
            snapshot.languageCode.startsWith("ja") ||
            Regex("[\\u3040-\\u30FF\\u4E00-\\u9FFF]").containsMatchIn(normalized)

        if (!usesCjk && normalized.isNotEmpty()) {
            normalized = normalized.replaceFirstChar { firstChar ->
                if (firstChar.isLowerCase()) {
                    firstChar.titlecase()
                } else {
                    firstChar.toString()
                }
            }
        }

        if (!finalize || !snapshot.smartPunctuation || hasTerminalPunctuation(normalized)) {
            return normalized
        }

        return when {
            looksLikeQuestion(normalized) -> normalized + if (usesCjk) "？" else "?"
            looksExcited(normalized) -> normalized + if (usesCjk) "！" else "!"
            else -> normalized + if (usesCjk) "。" else "."
        }
    }

    private fun hasTerminalPunctuation(value: String): Boolean {
        return value.endsWith(".") ||
            value.endsWith("!") ||
            value.endsWith("?") ||
            value.endsWith("。") ||
            value.endsWith("！") ||
            value.endsWith("？")
    }

    private fun looksLikeQuestion(value: String): Boolean {
        val lower = value.lowercase()
        return listOf(
            "吗",
            "么",
            "呢",
            "why",
            "how",
            "what",
            "when",
            "where",
            "can",
            "should",
        ).any { lower.contains(it) }
    }

    private fun looksExcited(value: String): Boolean {
        val lower = value.lowercase()
        return listOf(
            "太好了",
            "真棒",
            "awesome",
            "great",
            "amazing",
        ).any { lower.contains(it) }
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    private fun tintPill(view: TextView, fillColor: Int, strokeColor: Int, textColor: Int) {
        val drawable = view.background.mutate() as GradientDrawable
        drawable.setColor(fillColor)
        drawable.setStroke(dp(1), alpha(strokeColor, 0.26f))
        view.setTextColor(textColor)
    }

    private fun alpha(color: Int, fraction: Float): Int {
        val alpha = (255 * fraction).toInt().coerceIn(0, 255)
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    private fun blend(colorA: Int, colorB: Int, ratio: Float): Int {
        val inverse = 1f - ratio
        return Color.rgb(
            (Color.red(colorA) * inverse + Color.red(colorB) * ratio).toInt(),
            (Color.green(colorA) * inverse + Color.green(colorB) * ratio).toInt(),
            (Color.blue(colorA) * inverse + Color.blue(colorB) * ratio).toInt(),
        )
    }

    private fun getColorCompat(resId: Int): Int {
        return ContextCompat.getColor(this, resId)
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private fun formatElapsed(seconds: Int): String {
        val minutes = seconds / 60
        val remainder = seconds % 60
        return "$minutes:${remainder.toString().padStart(2, '0')}"
    }

    override fun onReadyForSpeech(params: Bundle?) = Unit

    override fun onBeginningOfSpeech() = Unit

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() {
        if (uiState == UiState.LISTENING) {
            uiState = UiState.PROCESSING
            renderProcessing()
        }
    }

    override fun onError(error: Int) {
        mainHandler.removeCallbacks(timerRunnable)
        waveformView.setActive(false)

        val fallback = normalizeTranscript(pendingTranscript, finalize = true)
        if (fallback.isNotEmpty()) {
            renderPreview(fallback)
            return
        }

        val message = when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "录音中断，请重试。"
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "麦克风权限不足，请去主 App 授权。"
            SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "网络不可用，暂时无法识别。"
            SpeechRecognizer.ERROR_NO_MATCH -> "没有识别到清晰语音。"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "识别器正忙，请稍后再试。"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "等待语音超时。"
            else -> "语音识别失败，请重试。"
        }
        renderIdle(message)
    }

    override fun onResults(results: Bundle?) {
        val transcript = firstRecognitionResult(results)
        val normalized = normalizeTranscript(transcript, finalize = true)
        if (normalized.isEmpty()) {
            renderIdle("没有识别到清晰语音，请再试一次。")
            return
        }
        renderPreview(normalized)
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val transcript = firstRecognitionResult(partialResults)
        if (transcript.isBlank()) {
            return
        }
        pendingTranscript = normalizeTranscript(transcript, finalize = false)
        previewText.text = pendingTranscript
        previewText.alpha = 0.96f
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    private fun firstRecognitionResult(bundle: Bundle?): String {
        val matches = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            .orEmpty()
        pendingTranscript = matches
        return matches
    }

    private enum class UiState {
        IDLE,
        LISTENING,
        PROCESSING,
        PREVIEW,
    }
}

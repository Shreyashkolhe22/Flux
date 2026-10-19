package com.example.flux

import android.graphics.Canvas
import android.graphics.Paint

/** 5x7 dot-matrix glyphs, the same ones the app draws for the FLUX wordmark. */
object DotFont {
    private val glyphs: Map<Char, List<String>> = mapOf(
        'A' to listOf("01110", "10001", "10001", "11111", "10001", "10001", "10001"),
        'B' to listOf("11110", "10001", "10001", "11110", "10001", "10001", "11110"),
        'C' to listOf("01110", "10001", "10000", "10000", "10000", "10001", "01110"),
        'D' to listOf("11110", "10001", "10001", "10001", "10001", "10001", "11110"),
        'E' to listOf("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
        'F' to listOf("11111", "10000", "10000", "11110", "10000", "10000", "10000"),
        'G' to listOf("01110", "10001", "10000", "10111", "10001", "10001", "01111"),
        'H' to listOf("10001", "10001", "10001", "11111", "10001", "10001", "10001"),
        'I' to listOf("01110", "00100", "00100", "00100", "00100", "00100", "01110"),
        'J' to listOf("00111", "00010", "00010", "00010", "00010", "10010", "01100"),
        'K' to listOf("10001", "10010", "10100", "11000", "10100", "10010", "10001"),
        'L' to listOf("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
        'M' to listOf("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
        'N' to listOf("10001", "11001", "10101", "10011", "10001", "10001", "10001"),
        'O' to listOf("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
        'P' to listOf("11110", "10001", "10001", "11110", "10000", "10000", "10000"),
        'Q' to listOf("01110", "10001", "10001", "10001", "10101", "10010", "01101"),
        'R' to listOf("11110", "10001", "10001", "11110", "10100", "10010", "10001"),
        'S' to listOf("01111", "10000", "10000", "01110", "00001", "00001", "11110"),
        'T' to listOf("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
        'U' to listOf("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
        'V' to listOf("10001", "10001", "10001", "10001", "10001", "01010", "00100"),
        'W' to listOf("10001", "10001", "10001", "10101", "10101", "11011", "10001"),
        'X' to listOf("10001", "10001", "01010", "00100", "01010", "10001", "10001"),
        'Y' to listOf("10001", "10001", "01010", "00100", "00100", "00100", "00100"),
        'Z' to listOf("11111", "00001", "00010", "00100", "01000", "10000", "11111"),
        '.' to listOf("0", "0", "0", "0", "0", "0", "1"),
        ' ' to listOf("00", "00", "00", "00", "00", "00", "00"),
    )

    /** Width in dot columns, including the gap after each character. */
    fun columns(text: String): Int =
        text.uppercase().sumOf { ch -> (glyphs[ch]?.get(0)?.length ?: 0).let { if (it == 0) 0 else it + 1 } }

    /**
     * Draws [text] with the top-left at ([left], [top]); each dot cell is [cell] px.
     * A "." is drawn with [accent] if given (the red full stop of the wordmark).
     */
    fun draw(canvas: Canvas, text: String, left: Float, top: Float, cell: Float, paint: Paint, accent: Paint? = null) {
        var x = 0
        for (ch in text.uppercase()) {
            val g = glyphs[ch] ?: continue
            val p = if (ch == '.' && accent != null) accent else paint
            for (row in g.indices) for (col in g[row].indices) {
                if (g[row][col] == '1') {
                    canvas.drawCircle(
                        left + (x + col) * cell + cell / 2,
                        top + row * cell + cell / 2,
                        if (ch == '.') cell * 0.5f else cell * 0.36f,
                        p,
                    )
                }
            }
            x += g[0].length + 1
        }
    }
}

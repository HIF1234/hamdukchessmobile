# Third-party notices

## Chess piece images (`assets/pieces/`)

The piece set by Colin M.L. Burnett ("cburnett"), taken from the `react-chessboard` package.
The cburnett set is published under several licences, including BSD. `react-chessboard`'s licence:

```
MIT License

Copyright (c) 2022 Ryan Gregory

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Packages

See `pubspec.yaml`. All direct dependencies are under permissive licences (MIT, BSD).

## Stockfish (bots)

The Android app includes **Stockfish 11**, unmodified, licensed under the GNU GPL v3
(`assets/licenses/GPL-3.0.txt`). It is a separate program (`android/app/src/main/jniLibs/*/
libstockfish.so`, built by `engine/build.sh`) that the app starts as its own process and talks
to only through UCI text commands on standard input and output (`lib/engine/uci_engine.dart`).
It is not linked into the app.

What the GPL requires, and where it's done:
- **Licence notice and text** in the app: Profile → About & licences (registered in `lib/main.dart`).
- **Complete corresponding source**, publicly available from the same place as the app:
  https://play.chess.hamduk.com.ng/opensource/stockfish-sf_11-source.tar.gz (official sf_11,
  unmodified) and the build script https://play.chess.hamduk.com.ng/opensource/stockfish-android-build.sh.
  If `engine/build.sh` changes, publish the new copy there too.
- **No changes** to Stockfish's code. If that ever changes, the modified source must be published.

Get a lawyer to confirm this set-up before the paid launch.

## Fonts (`assets/fonts/`)

DM Sans, Playfair Display, JetBrains Mono and Noto Sans, from Google Fonts, under the SIL Open Font
License 1.1 (`assets/fonts/OFL-*.txt`). The files are static weights instanced from the variable
fonts; Noto Sans is subset to Latin, IPA, combining marks and currency symbols.

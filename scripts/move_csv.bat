@echo off
setlocal
set REPO=C:\Users\Kunikata\projects\euphonauts-attendance-routine
set LOG=%REPO%\data\manual_csv\move_log.txt
echo ===== %date% %time% ===== >> "%LOG%"
REM --- 1. Downloadsフォルダから移動 ---
move /Y "C:\Users\Kunikata\Downloads\日次勤怠一覧_月末締め（翌月末日払い）_*.csv" "%REPO%\data\manual_csv\" >> "%LOG%" 2>&1
REM --- 2. 移動後、Downloadsに対象ファイルが残っていないか確認（移動漏れの検知） ---
dir "C:\Users\Kunikata\Downloads\日次勤怠一覧_月末締め（翌月末日払い）_*.csv" >nul 2>&1
if %ERRORLEVEL%==0 (
    echo [警告] Downloadsフォルダに未移動のCSVが残っています。移動処理を確認してください。 >> "%LOG%"
) else (
    echo 移動処理: Downloadsフォルダに残存ファイルなし（正常） >> "%LOG%"
)
REM --- 3. gitリポジトリへ移動してコミット・プッシュ ---
cd /d "%REPO%"
git add data\manual_csv >> "%LOG%" 2>&1
REM 変更が無い場合、commitはエラー終了するが、それは異常ではないのでログにのみ残す
git commit -m "Update attendance CSV (automated, %date% %time%)" >> "%LOG%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo commit: 変更なし、または失敗（詳細は上のログを確認） >> "%LOG%"
) else (
    echo commit: 成功 >> "%LOG%"
)
REM --- 4. デフォルトブランチを確認してからpull→push（ブランチ不一致・[rejected] (fetch first) 事故防止） ---
set DEFAULT_BRANCH=
for /f "tokens=2 delims=:" %%b in ('git remote show origin ^| findstr "HEAD branch"') do set DEFAULT_BRANCH=%%b
REM 先頭に付与される半角スペースを除去
for /f "tokens=* delims= " %%c in ("%DEFAULT_BRANCH%") do set DEFAULT_BRANCH=%%c
if "%DEFAULT_BRANCH%"=="" (
    echo [エラー] リモートのデフォルトブランチを取得できませんでした。ネットワークまたは認証の問題の可能性があります。push を中止します。 >> "%LOG%"
) else (
    echo Default branch: %DEFAULT_BRANCH% >> "%LOG%"
    REM --- リモートに他セッションからの更新が入っている場合の push [rejected] (fetch first) 対策 ---
    git pull origin %DEFAULT_BRANCH% --no-edit >> "%LOG%" 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo pull: 失敗 >> "%LOG%"
        echo [エラー] pull失敗、手動確認が必要（コンフリクト等の可能性があります。push は行わず中止します） >> "%LOG%"
    ) else (
        echo pull: 成功 >> "%LOG%"
        git push origin HEAD:%DEFAULT_BRANCH% >> "%LOG%" 2>&1
        if %ERRORLEVEL% NEQ 0 (
            echo [エラー] git push に失敗しました。認証情報の期限切れ等の可能性があります。 >> "%LOG%"
        ) else (
            echo push: 成功（push先: %DEFAULT_BRANCH%） >> "%LOG%"
        )
    )
)
echo ===== 処理完了 %date% %time% ===== >> "%LOG%"
echo. >> "%LOG%"
REM --- 5. ログの保持件数を直近30回分に制限（クレジット節約・肥大化防止） ---
setlocal enabledelayedexpansion
set "TMPLOG=%TEMP%\move_log_trimmed.txt"
if exist "%TMPLOG%" del "%TMPLOG%"
set /a BLOCK_COUNT=0
for /f "delims=" %%l in ('findstr /n "^===== " "%LOG%"') do set /a BLOCK_COUNT+=1
if !BLOCK_COUNT! GTR 30 (
    powershell -NoProfile -Command ^
        "$lines = Get-Content -Path '%LOG%' -Encoding Default; " ^
        "$starts = (0..($lines.Count-1)) | Where-Object { $lines[$_] -match '^===== ' }; " ^
        "$keepFrom = $starts[$starts.Count-30]; " ^
        "$lines[$keepFrom..($lines.Count-1)] | Set-Content -Path '%TMPLOG%' -Encoding Default"
    move /Y "%TMPLOG%" "%LOG%" >nul
)
endlocal
endlocal

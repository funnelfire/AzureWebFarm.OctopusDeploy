rmdir Environment -Force -ErrorAction SilentlyContinue -Recurse
mkdir Environment
robocopy /E . Environment
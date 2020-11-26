suite=abc ^
  def ^
  ghi ^
  jkl
for %%s in ("%suite%") do (
  echo %%s
  tasklist /FI "USERNAME eq jenkins" | sort
)
REM tasklist /FI "USERNAME eq jenkins" | sort
echo finished

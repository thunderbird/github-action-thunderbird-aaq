# github-action-thunderbird-aaq
github action to get all the Thunderbird SUMO forum questions aka Ask a Question or AAQ

## 2023-06-04 how to print a count of all the CSV files in 2023

```bash
cd 2023
find . -name '*.csv' -print | sort | xargs -n 1 mlr --csv count then put 'print FILENAME'
```

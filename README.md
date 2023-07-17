# github-action-thunderbird-aaq
github action to get all the Thunderbird SUMO forum questions aka Ask a Question or AAQ

## 2023-07-16 How To concat CSV files and then add a link field and then open in browser

```bash
csvstack 2023-07-11-2023-07-11-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-12-2023-07-12-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-13-2023-07-13-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-14-2023-07-14-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-15-2023-07-15-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-16-2023-07-16-thunderbird-creator-answers-desktop-all-locales.csv > tb115-2023-07-11-2023-07-16-questions.csv
mlr --csv put -f ../make-question-link.mlr tb115-2023-07-11-2023-07-16-questions.csv \
> with-linktb115-2023-07-11-2023-07-16-questions.csv
mlr --csv cut -f link with-linktb115-2023-07-11-2023-07-16-questions.csv | xargs -n 1 open
```
## 2023-06-04 how to print a count of all the CSV files in 2023

```bash
cd 2023
find . -name '*.csv' -print | sort | xargs -n 1 mlr --csv count then put 'print FILENAME'
```

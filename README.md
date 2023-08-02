# github-action-thunderbird-aaq
github action to get all the Thunderbird SUMO forum questions aka Ask a Question or AAQ

### 2023-08-02 csvstack doesn't work as well as mlr here's how to concat CSV files
```bash
mlr --csv cat 2023-07-21-2023-07-21-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-22-2023-07-22-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-23-2023-07-23-thunderbird-creator-answers-desktop-all-locales.csv \
2023-07-24-2023-07-24-thunderbird-creator-answers-desktop-all-locales.csv > \
thunderbird-2023-07-21-2023-07-24-questions.csv
```
## 2023-08-01 Pause 10 seconds between opening SUMO Thunderbird SUMO questions for a particular day
```bash
mlr --csv put -f ../make-question-link.mlr \                               
2023-07-19-2023-07-19-thunderbird-creator-answers-desktop-all-locales.csv | \
mlr --csv cut -f link | xargs -n 1 -I % sh -c 'sleep 10; open %;'
```
## 2023-07-25 how to open SUMO Thunderbird question links for a particular day
```bash
mlr --csv put -f ../make-question-link.mlr \
2023-07-17-2023-07-17-thunderbird-creator-answers-desktop-all-locales.csv | \
mlr --csv cut -f link | xargs -n 1 open
```

## 2023-07-23 creating thunderbird swag graphics april 1-june 30, 2023
```bash
mlr --csv cat 2023-04*creator*.csv 2023-05*creator*.csv 2023-06*creator*.csv >thunderbird-2023-04-01-2023-06-30-questions.csv
mlr --csv cat  2023-04*answers-for*.csv 2023-05*answers-for*.csv 2023-06*answers-for*.csv  > thunderbird-2023-04-01-2023-06-30-answers.csv
mlr --csv sort -n id thunderbird-2023-04-01-2023-06-30-questions.csv >sorted-by-id-thunderbird-2023-04-01-2023-06-30-questions.csv
mlr --csv sort -n id thunderbird-2023-04-01-2023-06-30-answers.csv >sorted-by-id-thunderbird-2023-04-01-2023-06-30-answers.csv
```
## 2023-07-17 how to create SQLite database

* first install pandas 1.4 as per https://github.com/simonw/csvs-to-sqlite/issues/88
* and then install csvs-to-sqlite

```bash
csvs-to-sqlite with-linktb115-2023-07-11-2023-07-16-questions.csv -dt created -dt updated \
with-linktb115-2023-07-11-2023-07-16-questions.db
```
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

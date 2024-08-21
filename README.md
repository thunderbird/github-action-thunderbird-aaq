# github-action-thunderbird-aaq
github action to get all the Thunderbird SUMO forum questions aka Ask a Question or AAQ

### 2024-08-21 A better way to open a day's questions (that skips the CSV header row)
```bash
 mlr --csv --headerless-csv-output put -f ../make-question-link.mlr \
then cut -f link \
2024-08-20-2024-08-20-thunderbird-creator-answers-desktop-all-locales.csv \ 
| xargs -n 1 -I % sh -c 'sleep 5; open %;' #5 seconds is better than 10, 10 is too long
```

### 2023-12-11 bundle install if you change the Gemfile
```bash
# REMINDER :-) if you change the gemfile, bundle install!!!!!
bundle install
```
### 2023-12-10 get all time CSVs
```bash
mlr --csv sort -f id ../2023/*-thunderbird-regex-matches.csv > alltime-thunderbird-regex-matches.csv
mlr --csv sort -f date ../2023/*-thunderbird-daily-summary.csv > alltime-thunderbird-daily-summary.csv
```
### No need for a script to combine CSV files! use mlr!
tl;dr don't use concatenate-multiple-sumo-question-or-answer-files.rb :-)
```bash
cd SQLITE
mlr --csv sort -f id ../2023/*thunderbird-creator-answers-desktop-all-locales.csv \
> 2023-yearly-thunderbird-questions.csv
mlr --csv sort -f id ../2023/*thunderbird-answers-for-questions-desktop.csv \
> 2023-yearly-thunderbird-answers.csv
```

### 2023-12-05 get daily regular expression summaries
```bash
./get_regular_expression_matches_for_n_days_starting.rb 2023 4 1 247
./get_daily-summary-csv-for-n-days-starting.rb 2023 4 1 247
cd 2023
mlr --csv sort -f date 2023*-thunderbird-daily*.csv >2023-thunderbird-daily-regex-summmary.csv
csvs-to-sqlite 2023-thunderbird-daily-regex-summmary.csv -dt date ../SQLITE/2023-thunderbird-daily-regex-summary.db 
```
### 2023-08-15 concat all the questions and answers from July 11-August 15, 2023 i.e. from start of TB115 release and then search them
```bash
./concatenate-multiple-sumo-question-or-answer-files.rb 2023 7 11 2023 8 15 questions
./concatenate-multiple-sumo-question-or-answer-files.rb 2023 7 11 2023 8 15 answers
```
which creates the files:
* CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/[thunderbird-desktop-questions-2023-07-11-2023-08-15.csv](https://raw.githubusercontent.com/rtanglao/github-action-thunderbird-aaq/main/CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/thunderbird-desktop-questions-2023-07-11-2023-08-15.csv)
* CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/[thunderbird-desktop-answers-2023-07-11-2023-08-15.csv](https://raw.githubusercontent.com/rtanglao/github-action-thunderbird-aaq/main/CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/thunderbird-desktop-answers-2023-07-11-2023-08-15.csv)

#### you can than then search using datasette lite using SQLite (joins etc)

* https://lite.datasette.io/?csv=https://raw.githubusercontent.com/rtanglao/github-action-thunderbird-aaq/main/CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/thunderbird-desktop-questions-2023-07-11-2023-08-15.csv&csv=https://raw.githubusercontent.com/rtanglao/github-action-thunderbird-aaq/main/CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/thunderbird-desktop-answers-2023-07-11-2023-08-15.csv <-- to search the tables
* search for all of wayne's replies aka answers:
* SQLite is:
  ```sql
  select rowid, id, question_id, created, updated, content, creator, is_spam, num_helpful, num_unhelpful, link from [thunderbird-desktop-answers-2023-07-11-2023-08-15] where "creator" = :p0 order by rowid limit 101
  p0=wsmwk
  ````
  * URL for above SQLite query is: https://lite.datasette.io/?csv=https://raw.githubusercontent.com/rtanglao/github-action-thunderbird-aaq/main/CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/thunderbird-desktop-questions-2023-07-11-2023-08-15.csv&csv=https://raw.githubusercontent.com/rtanglao/github-action-thunderbird-aaq/main/CSV_BY_TIME_PERIOD_USUALLY_BY_MONTH/thunderbird-desktop-answers-2023-07-11-2023-08-15.csv#/data?sql=select+rowid%2C+id%2C+question_id%2C+created%2C+updated%2C+content%2C+creator%2C+is_spam%2C+num_helpful%2C+num_unhelpful%2C+link+from+%5Bthunderbird-desktop-answers-2023-07-11-2023-08-15%5D+where+%22creator%22+%3D+%3Ap0+order+by+rowid+limit+101&p0=wsmwk


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
mlr --csv cut -f link | xargs -n 1 -I % sh -c 'sleep 5; open %;' #5 seconds is better than 10, 10 is too long
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

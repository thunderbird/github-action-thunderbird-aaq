def get_questions_filename(yyyy1, mm1, dd1, yyyy2, mm2, dd2)
  fn_str = '%<y1>4.4d-%<m1>2.2d-%<d1>2.2d-%<y2>4.4d-%<m2>2.2d-%<d2>2.2d'
  fn_str += '-thunderbird-creator-answers-desktop-all-locales.csv'
  format(fn_str, y1: yyyy1, m1: mm1, d1: dd1, y2: yyyy2, m2: mm2, d2: dd2)
end

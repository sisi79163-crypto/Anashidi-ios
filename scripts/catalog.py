import json
from pathlib import Path
names='الفاتحة|البقرة|آل عمران|النساء|المائدة|الأنعام|الأعراف|الأنفال|التوبة|يونس|هود|يوسف|الرعد|إبراهيم|الحجر|النحل|الإسراء|الكهف|مريم|طه|الأنبياء|الحج|المؤمنون|النور|الفرقان|الشعراء|النمل|القصص|العنكبوت|الروم|لقمان|السجدة|الأحزاب|سبأ|فاطر|يس|الصافات|ص|الزمر|غافر|فصلت|الشورى|الزخرف|الدخان|الجاثية|الأحقاف|محمد|الفتح|الحجرات|ق|الذاريات|الطور|النجم|القمر|الرحمن|الواقعة|الحديد|المجادلة|الحشر|الممتحنة|الصف|الجمعة|المنافقون|التغابن|الطلاق|التحريم|الملك|القلم|الحاقة|المعارج|نوح|الجن|المزمل|المدثر|القيامة|الإنسان|المرسلات|النبأ|النازعات|عبس|التكوير|الانفطار|المطففين|الانشقاق|البروج|الطارق|الأعلى|الغاشية|الفجر|البلد|الشمس|الليل|الضحى|الشرح|التين|العلق|القدر|البينة|الزلزلة|العاديات|القارعة|التكاثر|العصر|الهمزة|الفيل|قريش|الماعون|الكوثر|الكافرون|النصر|المسد|الإخلاص|الفلق|الناس'.split('|')
assert len(names)==114
catalog=[dict(id=f'q{i:03}',title='سورة '+n,artist='مشاري راشد العفاسي',kind='quran',number=str(i),url=f'https://server8.mp3quran.net/afs/{i:03}.mp3',source='https://www.mp3quran.net/ar/afs') for i,n in enumerate(names,1)]
base='https://server1.samaanetwork.net/Full.Albums/Mishary.Alafasy/Album.Tara7ame.Ya.Qloob/'
for id,title,file in [('n-rahman','رحمن يا رحمن','10-Ra7man.Ya.Ra7man.mp3'),('n-rattel','رتل','09-Rattel.2.mp3'),('n-insan','إنسان','07-Insan.mp3')]:
 catalog.append(dict(id=id,title=title,artist='مشاري راشد العفاسي',kind='nasheed',url=base+file,source='https://play.samaanetwork.net/music/ra7man/'))
Path('www/catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2))

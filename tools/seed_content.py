"""Rebuild original draft starter material. Never substitutes for human review."""
import json
from pathlib import Path
from translations import extras

ROOT = Path(__file__).resolve().parents[1]

def write(path, value):
    (ROOT / path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")

KEYS = "emergency library map downloads settings search offline ready help learn all basic advanced bookmarks language appearance light dark system text_size storage wifi_only installed available download remove cancel sources draft checklist compass locate save_place no_results essential privacy test_center".split()
LABELS = {
"en": "Emergency|Library|Map|Downloads|Settings|Search your offline library|OFFLINE READY|Prepare for the unexpected|I need help now|Learn & repair|All topics|Basic|Advanced|Bookmarks|Language|Appearance|Light|Dark|System|Text size|Storage budget|Wi-Fi only|Installed|Available packs|Download|Remove|Cancel|Sources|Draft · awaiting expert review|Preparation checklist|Compass|Find my location|Save a place|No matching installed articles|Essential handbook|Privacy & about|Test Center",
"ar": "طوارئ|المكتبة|الخريطة|التنزيلات|الإعدادات|ابحث في مكتبتك دون اتصال|متاح دون اتصال|استعد للطوارئ|أحتاج مساعدة الآن|تعلّم وأصلح|كل المواضيع|أساسي|متقدم|المحفوظات|اللغة|المظهر|فاتح|داكن|النظام|حجم النص|حد التخزين|واي فاي فقط|مثبّت|حزم متاحة|تنزيل|إزالة|إلغاء|المصادر|مسودة · تنتظر مراجعة مختص|قائمة الاستعداد|البوصلة|تحديد موقعي|حفظ مكان|لا توجد مقالات مطابقة مثبتة|الدليل الأساسي|الخصوصية وحول التطبيق|مركز الاختبار",
"ml": "അടിയന്തരം|ലൈബ്രറി|ഭൂപടം|ഡൗൺലോഡുകൾ|ക്രമീകരണങ്ങൾ|ഓഫ്‌ലൈൻ ലൈബ്രറിയിൽ തിരയുക|ഓഫ്‌ലൈൻ ലഭ്യമാണ്|അപ്രതീക്ഷിത സാഹചര്യങ്ങൾക്ക് തയ്യാറാകൂ|ഇപ്പോൾ സഹായം വേണം|പഠിക്കൂ നന്നാക്കൂ|എല്ലാ വിഷയങ്ങളും|അടിസ്ഥാനം|വിപുലമായത്|ബുക്ക്മാർക്കുകൾ|ഭാഷ|രൂപം|വെളിച്ചം|ഇരുണ്ടത്|സിസ്റ്റം|അക്ഷര വലുപ്പം|സംഭരണ പരിധി|വൈഫൈ മാത്രം|ഇൻസ്റ്റാൾ ചെയ്തത്|ലഭ്യമായ പാക്കുകൾ|ഡൗൺലോഡ്|നീക്കം|റദ്ദാക്കുക|ഉറവിടങ്ങൾ|കരട് · വിദഗ്ധ പരിശോധന വേണം|തയ്യാറെടുപ്പ് പട്ടിക|ദിശാസൂചി|എന്റെ സ്ഥാനം|സ്ഥലം സൂക്ഷിക്കുക|ലേഖനങ്ങൾ കണ്ടെത്തിയില്ല|അവശ്യ കൈപ്പുസ്തകം|സ്വകാര്യതയും വിവരങ്ങളും|പരിശോധന കേന്ദ്രം",
"hi": "आपातकाल|पुस्तकालय|नक्शा|डाउनलोड|सेटिंग्स|ऑफ़लाइन पुस्तकालय खोजें|ऑफ़लाइन उपलब्ध|आपात स्थिति के लिए तैयार रहें|अभी मदद चाहिए|सीखें और मरम्मत करें|सभी विषय|बुनियादी|उन्नत|बुकमार्क|भाषा|रूप|हल्का|गहरा|सिस्टम|अक्षर आकार|स्टोरेज सीमा|केवल वाई-फ़ाई|इंस्टॉल किया गया|उपलब्ध पैक|डाउनलोड|हटाएँ|रद्द करें|स्रोत|मसौदा · विशेषज्ञ समीक्षा बाकी|तैयारी सूची|कंपास|मेरा स्थान खोजें|स्थान सहेजें|कोई लेख नहीं मिला|आवश्यक पुस्तिका|गोपनीयता और जानकारी|परीक्षण केंद्र",
"ta": "அவசரம்|நூலகம்|வரைபடம்|பதிவிறக்கங்கள்|அமைப்புகள்|ஆஃப்லைன் நூலகத்தில் தேடவும்|ஆஃப்லைனில் கிடைக்கும்|அவசரநிலைக்குத் தயாராகுங்கள்|இப்போது உதவி தேவை|கற்றலும் பழுதுபார்ப்பும்|அனைத்து தலைப்புகள்|அடிப்படை|மேம்பட்டது|புக்மார்க்குகள்|மொழி|தோற்றம்|வெளிச்சம்|இருள்|கணினி|எழுத்து அளவு|சேமிப்பு வரம்பு|வைஃபை மட்டும்|நிறுவப்பட்டது|கிடைக்கும் தொகுப்புகள்|பதிவிறக்கு|நீக்கு|ரத்து|ஆதாரங்கள்|வரைவு · நிபுணர் ஆய்வு தேவை|தயார்நிலை பட்டியல்|திசைகாட்டி|எனது இருப்பிடம்|இடத்தைச் சேமி|கட்டுரைகள் இல்லை|அத்தியாவசிய கையேடு|தனியுரிமை மற்றும் விவரம்|சோதனை மையம்",
"te": "అత్యవసరం|గ్రంథాలయం|పటం|డౌన్‌లోడ్‌లు|సెట్టింగ్‌లు|ఆఫ్‌లైన్ గ్రంథాలయంలో వెతకండి|ఆఫ్‌లైన్‌లో అందుబాటులో|అత్యవసర పరిస్థితికి సిద్ధంకండి|ఇప్పుడు సహాయం కావాలి|నేర్చుకోండి మరమ్మతు చేయండి|అన్ని అంశాలు|ప్రాథమిక|అధునాతన|బుక్‌మార్క్‌లు|భాష|రూపం|కాంతి|చీకటి|సిస్టమ్|అక్షర పరిమాణం|నిల్వ పరిమితి|వైఫై మాత్రమే|ఇన్‌స్టాల్ అయింది|అందుబాటులో ప్యాక్‌లు|డౌన్‌లోడ్|తొలగించు|రద్దు|మూలాలు|ముసాయిదా · నిపుణుల సమీక్ష అవసరం|సన్నద్ధత జాబితా|దిక్సూచి|నా స్థానం|స్థలాన్ని భద్రపరచు|వ్యాసాలు కనుగొనబడలేదు|ముఖ్యమైన పుస్తకం|గోప్యత మరియు సమాచారం|పరీక్ష కేంద్రం",
"es": "Emergencia|Biblioteca|Mapa|Descargas|Ajustes|Buscar en la biblioteca sin conexión|SIN CONEXIÓN|Prepárate para lo inesperado|Necesito ayuda ahora|Aprender y reparar|Todos los temas|Básico|Avanzado|Guardados|Idioma|Apariencia|Claro|Oscuro|Sistema|Tamaño del texto|Límite de almacenamiento|Solo Wi-Fi|Instalado|Paquetes disponibles|Descargar|Eliminar|Cancelar|Fuentes|Borrador · pendiente de revisión|Lista de preparación|Brújula|Buscar mi ubicación|Guardar lugar|No hay artículos coincidentes|Manual esencial|Privacidad e información|Centro de pruebas",
"fr": "Urgence|Bibliothèque|Carte|Téléchargements|Réglages|Rechercher hors connexion|HORS CONNEXION|Préparez-vous à l’imprévu|Besoin d’aide maintenant|Apprendre et réparer|Tous les sujets|Essentiel|Avancé|Favoris|Langue|Apparence|Clair|Sombre|Système|Taille du texte|Limite de stockage|Wi-Fi uniquement|Installé|Packs disponibles|Télécharger|Supprimer|Annuler|Sources|Brouillon · en attente de validation|Liste de préparation|Boussole|Trouver ma position|Enregistrer un lieu|Aucun article correspondant|Guide essentiel|Confidentialité et informations|Centre de tests",
"ru": "Экстренная помощь|Библиотека|Карта|Загрузки|Настройки|Поиск в офлайн-библиотеке|БЕЗ ИНТЕРНЕТА|Подготовьтесь к неожиданному|Нужна помощь сейчас|Обучение и ремонт|Все темы|Основы|Расширенные|Закладки|Язык|Оформление|Светлое|Тёмное|Системное|Размер текста|Лимит хранилища|Только Wi-Fi|Установлено|Доступные пакеты|Скачать|Удалить|Отмена|Источники|Черновик · нужна проверка|Список подготовки|Компас|Моё местоположение|Сохранить место|Статьи не найдены|Основной справочник|Конфиденциальность и сведения|Центр тестирования",
}
for code, value in LABELS.items():
    values = value.split("|")
    assert len(values) == len(KEYS), (code, len(values), len(KEYS))
    write(f"assets/i18n/{code}.json", {**dict(zip(KEYS, values)), **extras(code)})

ARTICLES = []
def article(id, title, category, summary, steps, cautions, source, *,
            language="en", level="basic", aliases=None, illustration="kit", equipment=None):
    value = dict(id=id, title=title, category=category, summary=summary, language=language,
        level=level, region="Global", audience="General public" if level=="basic" else "Trained readers",
        prerequisites=equipment or [], aliases=aliases or [], keywords=[category, id.replace("-", " ")],
        sections=[{"heading": LABELS[language].split("|")[9], "steps": steps}],
        cautions=cautions, sources=[source], license="Original editorial summary; source rights review pending",
        review_status="draft", reviewer=None, reviewed_at=None, translation_review="pending",
        updated_at="2026-10-20", illustrations=[f"assets/illustrations/{illustration}.svg"],
        related=[])
    ARTICLES.append(value)
    return value

# Small, intentionally conservative multilingual offline cards. Extended
# translations are not invented or labelled complete.
ESSENTIAL = {
"en": ["Before an emergency","Prepare your essentials","Save contacts offline.","Pack water and prescribed medicines.","Choose a meeting place.",
       "When you are lost","Pause and assess","Stop in a safe place.","Conserve battery.","Signal your location."],
"ar": ["قبل الطوارئ","جهّز الضروريات","احفظ جهات الاتصال دون إنترنت.","جهّز الماء وأدويتك الموصوفة.","حدد مكانًا للقاء.",
       "عندما تضل الطريق","توقف وقيّم الوضع","توقف في مكان آمن.","حافظ على البطارية.","أشر إلى موقعك."],
"ml": ["അടിയന്തരാവസ്ഥയ്ക്ക് മുമ്പ്","അവശ്യവസ്തുക്കൾ തയ്യാറാക്കുക","ബന്ധപ്പെടാനുള്ള വിവരങ്ങൾ ഓഫ്‌ലൈനിൽ സൂക്ഷിക്കുക.","വെള്ളവും നിർദേശിച്ച മരുന്നുകളും കരുതുക.","കണ്ടുമുട്ടാനുള്ള സ്ഥലം നിശ്ചയിക്കുക.",
       "വഴി തെറ്റിയാൽ","നിർത്തി വിലയിരുത്തുക","സുരക്ഷിതമായ സ്ഥലത്ത് നിൽക്കുക.","ബാറ്ററി ലാഭിക്കുക.","സ്ഥാനം അറിയിക്കാൻ അടയാളം നൽകുക."],
"hi": ["आपातकाल से पहले","ज़रूरी सामान तैयार करें","संपर्क ऑफ़लाइन सहेजें।","पानी और निर्धारित दवाएँ रखें।","मिलने का स्थान तय करें।",
       "रास्ता भटकने पर","रुकें और स्थिति समझें","सुरक्षित स्थान पर रुकें।","बैटरी बचाएँ।","अपनी जगह का संकेत दें।"],
"ta": ["அவசரநிலைக்கு முன்","அத்தியாவசியங்களைத் தயார் செய்யவும்","தொடர்புகளை ஆஃப்லைனில் சேமிக்கவும்.","தண்ணீரும் பரிந்துரைக்கப்பட்ட மருந்துகளும் வைத்திருக்கவும்.","சந்திக்கும் இடத்தை முடிவுசெய்யவும்.",
       "வழி தவறினால்","நின்று நிலையை ஆராயவும்","பாதுகாப்பான இடத்தில் நிற்கவும்.","பேட்டரியைச் சேமிக்கவும்.","இருப்பிடத்தை உணர்த்தவும்."],
"te": ["అత్యవసర పరిస్థితికి ముందు","అవసరమైనవి సిద్ధం చేయండి","పరిచయాలను ఆఫ్‌లైన్‌లో భద్రపరచండి.","నీరు మరియు సూచించిన మందులు ఉంచండి.","కలిసే ప్రదేశాన్ని ఎంచుకోండి.",
       "దారి తప్పినప్పుడు","ఆగి పరిస్థితిని అంచనా వేయండి","సురక్షిత ప్రదేశంలో ఆగండి.","బ్యాటరీని ఆదా చేయండి.","మీ స్థానాన్ని సూచించండి."],
"es": ["Antes de una emergencia","Prepara lo esencial","Guarda contactos sin conexión.","Lleva agua y medicamentos recetados.","Acuerda un punto de encuentro.",
       "Si te pierdes","Detente y evalúa","Detente en un lugar seguro.","Ahorra batería.","Señala tu ubicación."],
"fr": ["Avant une urgence","Préparez l’essentiel","Enregistrez vos contacts hors connexion.","Prévoyez eau et médicaments prescrits.","Choisissez un lieu de rendez-vous.",
       "Si vous êtes perdu","Arrêtez-vous et évaluez","Arrêtez-vous dans un endroit sûr.","Économisez la batterie.","Signalez votre position."],
"ru": ["До чрезвычайной ситуации","Подготовьте необходимое","Сохраните контакты без интернета.","Запасите воду и назначенные лекарства.","Выберите место встречи.",
       "Если вы заблудились","Остановитесь и оцените обстановку","Остановитесь в безопасном месте.","Берегите заряд батареи.","Обозначьте своё местоположение."],
}
for lang, v in ESSENTIAL.items():
    article("prepare", v[0], "preparedness", v[1], v[2:5], [],
            "https://www.ready.gov/kit", language=lang)
    article("lost", v[5], "wilderness", v[6], v[7:10], [],
            "https://www.nps.gov/articles/000/hiking-safety.htm", language=lang, illustration="compass")

article("flood", "Flood: move away from rising water", "disasters",
        "Recognize immediate danger and choose a safer location.",
        ["Move to higher ground when safe and follow local evacuation directions.",
         "Avoid walking or driving through floodwater; depth and road damage can be hidden.",
         "Keep away from fallen wires and electrical equipment exposed to water."],
        ["A saved map cannot tell you whether a road is passable."],
        "https://www.ready.gov/floods", illustration="flood")
article("earthquake", "Earthquake: protect yourself during shaking", "disasters",
        "Reduce exposure to falling objects.",
        ["Drop, take cover under sturdy furniture if available, and hold on.",
         "Stay away from windows. Do not rush outside during shaking.",
         "After shaking stops, check for hazards and be ready for aftershocks."],
        ["Adapt protective actions to your mobility and immediate surroundings."],
        "https://www.ready.gov/earthquakes", illustration="shelter")
article("desert", "Lost in a desert", "wilderness", "Reduce heat exposure while making yourself easier to find.",
        ["Seek shade and avoid unnecessary exertion in the hottest part of the day.",
         "If a vehicle is in a safe location, staying with it can make you easier to locate.",
         "Record your coordinates and signal rescuers when possible; do not rely on mobile reception."],
        ["Confusion, collapse, or severe illness needs urgent help. There is no universal survival countdown."],
        "https://www.nps.gov/deva/planyourvisit/safety.htm", illustration="compass")
article("water", "Water: treatment and storage", "water", "Match treatment to the contamination risk.",
        ["Use a known safe water source when available.",
         "For microbial contamination, boil clear water for one minute; above 6,500 feet use three minutes.",
         "Cool safely and store in clean, covered food-grade containers."],
        ["Boiling and disinfection do not make fuel- or toxic-chemical-contaminated water safe.",
         "A cloth removes sediment, not all pathogens."],
        "https://www.cdc.gov/water-emergency/about/index.html", illustration="water")
article("distillation", "Distillation: understand the limits", "water",
        "A reference to the process, equipment, and limitations.",
        ["Distillation evaporates water and collects condensed vapor in a separate clean container.",
         "Use equipment designed for the process and follow its instructions.",
         "Protect treated water from recontamination."],
        ["Some volatile contaminants can pass into the condensate. Unknown contamination requires a safer source.",
         "Never heat a sealed improvised vessel. Steam and hot surfaces cause burns."],
        "https://www.cdc.gov/drinking-water/about/about-home-water-treatment-systems.html",
        illustration="water", level="advanced", equipment=["Purpose-built distiller", "Safe power or heat source"])
article("first-aid", "First aid: assess before helping", "medical", "Start with scene safety and request qualified help.",
        ["Check for hazards before approaching an injured person.",
         "Contact available emergency services and follow dispatcher instructions.",
         "Use first-aid techniques you have been trained to perform."],
        ["This reference is not a medical device and does not diagnose or treat conditions.",
         "Seek professional medical advice before making medical decisions."],
        "https://www.redcross.org/take-a-class/first-aid/performing-first-aid")
med = article("paracetamol", "Paracetamol / acetaminophen", "medicines",
        "General medicine reference: pain and fever relief.",
        ["Check the active ingredients in every product; combination cold medicines may contain the same ingredient.",
         "Follow the product label and your clinician's instructions.",
         "Keep the original packaging and protect medicines from excess heat and moisture."],
        ["Too much acetaminophen can cause severe liver damage. Suspected overdose needs urgent medical help even without symptoms.",
         "Ask a clinician about liver disease, alcohol use, interactions, pregnancy, or treatment for a child."],
        "https://medlineplus.gov/druginfo/meds/a681004.html", aliases=["acetaminophen", "paracetamol", "APAP"])
med["medicine"] = {"generic_name": "Acetaminophen", "uses": ["Pain", "Fever"],
  "interactions": ["Review all medicines with a clinician or pharmacist"],
  "storage": "Follow the specific product label", "dose_calculator": False}
article("outbreak", "Outbreaks: reduce exposure", "outbreaks", "Use disease-specific advice from health authorities.",
        ["Wash hands and keep drinking water and food preparation hygienic.",
         "Improve ventilation where appropriate for respiratory infections.",
         "Plan how a sick household member can receive care and seek help."],
        ["This downloaded article is not a live outbreak alert. Precautions differ by disease."],
        "https://www.cdc.gov/respiratory-viruses/prevention/index.html")
article("foraging", "Foraging: identification comes first", "food", "Regional expertise matters more than a resemblance in a picture.",
        ["Learn local species with a qualified expert before an emergency.",
         "Compare multiple distinguishing features and poisonous lookalikes.",
         "Use familiar, safely stored food when identification is uncertain."],
        ["Do not eat an unknown plant or mushroom based on this app or an image.",
         "This starter pack contains no verified edible-species identification guide."],
        "https://www.poison.org/articles/plant")
article("cooking", "Cooking during a power outage", "cooking", "Prepare food without introducing fuel or contamination hazards.",
        ["Choose shelf-stable foods that need little preparation.",
         "Keep raw and ready-to-eat foods separate and clean tools with safe water.",
         "Use cooking equipment only in locations allowed by its manufacturer."],
        ["Charcoal grills and fuel-burning camping stoves must not be used indoors or in enclosed spaces."],
        "https://www.cdc.gov/carbon-monoxide/about/index.html")
article("food-storage", "Food storage when refrigeration fails", "cooking", "Protect food before and during outages.",
        ["Keep refrigerator and freezer doors closed as much as possible.",
         "Use an appliance thermometer and follow food-specific time and temperature guidance.",
         "Discard food when safety is uncertain; tasting cannot determine safety."],
        ["Preservation methods need validated recipes and equipment. Do not improvise canning procedures."],
        "https://www.foodsafety.gov/food-safety-charts/food-safety-during-power-outage")
article("sanitation", "Sanitation when services are interrupted", "sanitation", "Separate waste, drinking water, and food.",
        ["Choose a waste arrangement compatible with local conditions and public-health advice.",
         "Keep waste away from water sources and food storage.",
         "Maintain a hand-cleaning station with safe water and soap."],
        ["Floodwater and sewage may carry hazardous contamination."],
        "https://www.cdc.gov/water-emergency/about/index.html")
article("electronics", "A low-voltage device will not charge", "electronics", "Check simple causes before opening equipment.",
        ["Disconnect the device and inspect accessible cables for damage.",
         "Try a known compatible cable and power source if safe.",
         "Consult the device's model-specific manual before disassembly."],
        ["Stop if a battery is swollen, leaking, unusually hot, or damaged.",
         "Do not open mains power supplies or repair live electrical equipment."],
        "https://www.ifixit.com/Wiki/Lithium-ion_Battery_Safety", illustration="repair",
        equipment=["Manufacturer instructions", "Compatible charging cable"])
article("mechanical", "Mechanical troubleshooting", "mechanical", "Inspect before replacing parts.",
        ["Make the equipment stable and isolate its energy sources.",
         "Check visible fasteners, obstructions, wear, and alignment.",
         "Record the model and symptoms, then follow its service manual."],
        ["Springs, pressure, heat, and suspended loads can store energy even when power is off.",
         "Safety-critical brakes, steering, and lifting equipment require competent inspection."],
        "https://www.osha.gov/control-hazardous-energy", illustration="repair")
article("solar", "Planning a small solar charging setup", "electronics", "Check compatibility across the whole power chain.",
        ["Read the panel, controller, battery, and device specifications.",
         "Use compatible rated components and the manufacturer's wiring instructions.",
         "Protect equipment from water and inspect connections before use."],
        ["Do not connect a bare solar panel directly to a battery unless the equipment explicitly supports that arrangement."],
        "https://www.energy.gov/energysaver/planning-home-solar-electric-system",
        illustration="repair", level="advanced", equipment=["Rated panel", "Compatible controller and battery"])
article("coding", "Offline coding: your first Python script", "computing",
        "Prepare the tools before connectivity is lost.",
        ["Install Python and save its documentation on your computer while online.",
         "Create hello.py containing: print('Hello, offline world!')",
         "Run python3 hello.py in a terminal on your computer. Save dependencies and examples in advance."],
        ["Code shown here is reference text. The mobile app does not execute downloaded programs."],
        "https://docs.python.org/3/tutorial/", level="basic", equipment=["Computer with Python installed"])
article("network", "Build a local network without internet", "networks", "Devices can communicate locally even without an uplink.",
        ["Power a router and connect devices to its local Wi-Fi network.",
         "Use a unique network password and record the router's local address.",
         "On a trusted test network, serve a dedicated folder from a computer using python3 -m http.server 8000; open its local IP and port on another device."],
        ["A local network does not restore global internet. The example server has no authentication or encryption; never expose private files or forward its port to the internet."],
        "https://docs.python.org/3/library/http.server.html", level="advanced",
        equipment=["Router", "Computer", "Power"])
article("satellite", "Satellite communication: prepare equipment", "communications",
        "Connectivity depends on supported hardware, service, and location.",
        ["Check device compatibility, service coverage, activation, and subscription requirements before travel.",
         "Download the manufacturer's instructions and practice an approved test.",
         "Use the device's instructions for sky visibility, antenna placement, and emergency messaging."],
        ["Installing this app does not add satellite capability. Availability depends on equipment, service, and region."],
        "https://support.apple.com/en-ie/105097", equipment=["Supported phone or satellite terminal"])
article("radio", "Radio communication essentials", "communications", "Prepare a compatible channel and operating procedure.",
        ["Read the equipment manual and local operating requirements.",
         "Agree on a channel, check-in schedule, and short message format.",
         "Test range with your group before relying on the radio."],
        ["Permitted frequencies and licensing differ by region. A phone alone is not a general-purpose radio transceiver."],
        "https://www.itu.int/en/ITU-D/Emergency-Telecommunications/Pages/default.aspx", equipment=["Compatible radios"])
article("shutdown", "Prepare for an internet shutdown", "preparedness", "Keep essential information and local coordination available.",
        ["Download maps, contacts, documents, and reference packs ahead of time.",
         "Agree on meeting points and offline check-in times.",
         "Keep charging equipment ready and learn the local communication tools you already have."],
        ["No app can guarantee connectivity during a shutdown. Local links still require power and compatible devices."],
        "https://www.accessnow.org/keepiton/", illustration="kit")
article("wildfire", "Wildfire evacuation readiness", "disasters", "Prepare to leave before routes are threatened.",
        ["Identify more than one evacuation route before fire approaches.",
         "Keep essentials ready and follow evacuation instructions.",
         "Avoid smoke exposure and do not enter a fire-affected area to retrieve belongings."],
        ["Offline maps do not show live fire boundaries or road closures."],
        "https://www.ready.gov/wildfires", illustration="shelter")
article("storm", "Storms and extreme weather", "disasters", "Know the safest shelter before the weather changes.",
        ["Choose a suitable shelter for your local hazards.",
         "Secure essential supplies and charged lights before severe conditions arrive.",
         "Follow local warnings when available; inspect damage only when safe."],
        ["Hazard-specific shelter advice differs. A downloaded reference is not a forecast."],
        "https://www.ready.gov/severe-weather", illustration="shelter")

write("assets/content/essential.json", {"schema_version": 1, "version": "1.0.0-draft", "articles": ARTICLES})
write("assets/content/catalog.json", {"schema_version": 1, "packs": [], "status": "Hosting not configured"})

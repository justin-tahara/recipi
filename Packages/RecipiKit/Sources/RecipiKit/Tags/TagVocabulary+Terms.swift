import Foundation

// The built-in vocabulary. Synonyms are matched after `normalized(_:)`, so
// case, accents and punctuation don't matter ("Végétarien" is
// "vegetarien"). Each term's own name always matches too. To add a
// language, add its words to the terms below; a test checks that no word
// belongs to two terms.

extension TagVocabulary {
    static let allTerms: [VocabularyTerm] = cuisines + meals + diets + traits

    // MARK: Cuisine

    static let cuisines: [VocabularyTerm] = [
        // Groups first, so they lead their row of chips.
        VocabularyTerm("Asian", .cuisine, [
            "pan asian", "asia", "asiatique", "asiatisch", "asiatische", "asiatico", "asiatica", "アジア料理", "アジアン",
        ], includes: ["Japanese", "Korean", "Chinese", "Thai", "Vietnamese", "Filipino", "Indian"]),
        VocabularyTerm("European", .cuisine, [
            "europe", "europeen", "europeenne", "europaisch", "europaische", "europeo", "europea",
        ], includes: ["Italian", "French", "Spanish", "Greek", "British", "German"]),
        VocabularyTerm("Latin American", .cuisine, [
            "latin", "latino", "latina", "latinoamericano", "latinoamericana", "amerique latine", "lateinamerikanisch",
        ], includes: ["Mexican", "Caribbean"]),
        VocabularyTerm("Mediterranean", .cuisine, [
            "mediterraneen", "mediterraneenne", "mediterran", "mediterrane", "mediterraneo", "mediterranea", "地中海料理",
        ], includes: ["Italian", "Spanish", "Greek", "Middle Eastern"]),

        VocabularyTerm("Italian", .cuisine, [
            "italiano", "italiana", "italien", "italienne", "italienisch", "italienische", "italiaans", "italia",
            "italy", 
            // Regional cuisines read as the country's.
            "romana", "romano", "siciliana", "siciliano", "toscana", "toscano", "napoletana", "napoletano", "pugliese",
            "ligure", "emiliana", "veneta", "sarda", "calabrese", "tuscan", "sicilian", "neapolitan", "イタリアン", "イタリア料理", "意大利菜",
        ]),
        VocabularyTerm("French", .cuisine, [
            "france", "provencal", "provencale", "lyonnaise", "bretonne", "alsacienne", "normande", "basque", "francais", "francaise", "franzosisch", "franzosische", "francese", "frances", "francesa",
            "フレンチ", "フランス料理", "法国菜",
        ]),
        VocabularyTerm("Spanish", .cuisine, [
            "spain", "espagnol", "espagnole", "spanisch", "spanische", "spagnolo", "spagnola", "espanol", "espanola",
            "スペイン料理",
        ]),
        VocabularyTerm("Greek", .cuisine, [
            "greece", "grec", "grecque", "griechisch", "griechische", "greco", "greca", "griego", "griega", "ギリシャ料理",
        ]),
        VocabularyTerm("British", .cuisine, [
            "english", "uk", "anglais", "anglaise", "britannique", "britisch", "englisch", "inglese", "britanico",
            "イギリス料理",
        ]),
        VocabularyTerm("German", .cuisine, [
            "germany", "schwabisch", "bayerisch", "bavarian", "swabian", "allemand", "allemande", "deutsch", "deutsche", "tedesco", "tedesca", "aleman", "alemana",
            "ドイツ料理",
        ]),
        VocabularyTerm("Middle Eastern", .cuisine, [
            "middle east", "lebanese", "turkish", "persian", "israeli", "moyen orient", "moyen oriental",
            "moyen orientale", "libanais", "mediorientale", "oriente medio", "levantine", "中東料理",
        ]),
        VocabularyTerm("Japanese", .cuisine, [
            "japan", "japonais", "japonaise", "japanisch", "japanische", "giapponese", "japones", "japonesa",
            "japans", "washoku", "和食", "日本料理", "和風", "日式",
        ]),
        VocabularyTerm("Korean", .cuisine, [
            "korea", "coreen", "coreenne", "koreanisch", "koreanische", "coreano", "coreana", "韓国料理", "韓国",
            "한식", "한국 요리", "韩国菜",
        ]),
        VocabularyTerm("Chinese", .cuisine, [
            "china", "sichuan", "szechuan", "cantonese", "hunan", "shanghainese", "chinois", "chinoise", "chinesisch", "chinesische", "cinese", "chino", "中華",
            "中華料理", "中国料理", "中餐", "中式", "中国菜",
        ]),
        VocabularyTerm("Thai", .cuisine, [
            "thailand", "thailandais", "thailandaise", "thailandese", "tailandes", "tailandesa", "thailandisch",
            "タイ料理", "泰国菜",
        ]),
        VocabularyTerm("Vietnamese", .cuisine, [
            "vietnam", "vietnamien", "vietnamienne", "vietnamita", "vietnamesisch", "vietnamesische", "ベトナム料理",
            "越南菜",
        ]),
        VocabularyTerm("Filipino", .cuisine, [
            "filipina", "philippine", "philippines", "philippin", "philippinisch", "フィリピン料理",
        ]),
        VocabularyTerm("Indian", .cuisine, [
            "india", "punjabi", "south indian", "north indian", "goan", "keralan", "indien", "indienne", "indisch", "indische", "indiano", "インド料理", "印度菜",
        ]),
        VocabularyTerm("Mexican", .cuisine, [
            "mexico", "oaxacan", "yucatecan", "mexicain", "mexicaine", "mexikanisch", "mexikanische", "messicano", "messicana", "mexicano",
            "mexicana", "tex mex", "texmex", "メキシコ料理", "墨西哥菜",
        ]),
        VocabularyTerm("Caribbean", .cuisine, [
            "caribeen", "caribeenne", "antillais", "karibisch", "caraibico", "caribeno", "caribena", "jamaican",
        ]),
        VocabularyTerm("American", .cuisine, [
            "usa", "cajun", "creole", "southern", "americain", "americaine", "amerikanisch", "amerikanische", "americano", "americana",
            "estadounidense", "アメリカ料理", "美式",
        ]),
    ]

    // MARK: Meal

    static let meals: [VocabularyTerm] = [
        VocabularyTerm("Breakfast", .meal, [
            "brunch", "breakfasts", "petit dejeuner", "colazione", "desayuno", "desayunos", "fruhstuck",
            "fruehstueck", "朝食", "朝ごはん", "朝ご飯", "早餐",
        ]),
        VocabularyTerm("Lunch", .meal, [
            "lunches", "dejeuner", "pranzo", "almuerzo", "mittagessen", "昼食", "昼ごはん", "昼ご飯", "ランチ", "午餐",
        ]),
        VocabularyTerm("Dinner", .meal, [
            "dinners", "primi piatti", "primo piatto", "primi", "supper", "main", "mains", "main course", "main courses", "main dish", "main dishes",
            "diner", "plat principal", "plats principaux", "piatto principale", "secondo", "secondi", "secondi piatti",
            "cena", "plato principal", "plato fuerte", "abendessen", "hauptgericht", "hauptspeise", "夕食", "晩ご飯",
            "晩御飯", "主菜", "メイン", "晚餐",
        ]),
        VocabularyTerm("Side", .meal, [
            "sides", "side dish", "side dishes", "accompaniment", "accompaniments", "accompagnement",
            "accompagnements", "contorno", "contorni", "guarnicion", "acompanamiento", "beilage", "beilagen", "副菜",
            "付け合わせ",
        ]),
        VocabularyTerm("Snack", .meal, [
            "snacks", "appetizer", "appetizers", "appetiser", "appetisers", "starter", "starters", "hors doeuvre",
            "hors doeuvres", "finger food", "antipasto", "antipasti", "aperitivo", "aperitif", "tapas",
            "amuse bouche", "vorspeise", "vorspeisen", "entrante", "entrantes", "botana", "botanas", "おつまみ", "前菜",
            "おやつ", "間食", "小吃",
        ]),
        VocabularyTerm("Dessert", .meal, [
            "desserts", "sweets", "sweet", "dolce", "dolci", "postre", "postres", "nachtisch", "nachspeise",
            "nachspeisen", "デザート", "スイーツ", "甜点", "甜品",
        ]),
        VocabularyTerm("Drink", .meal, [
            "drinks", "beverage", "beverages", "cocktail", "cocktails", "mocktail", "mocktails", "smoothie",
            "smoothies", "boisson", "boissons", "bevanda", "bevande", "bebida", "bebidas", "getrank", "getranke",
            "ドリンク", "飲み物", "饮品",
        ]),
    ]

    // MARK: Diet

    static let diets: [VocabularyTerm] = [
        VocabularyTerm("Vegetarian", .diet, [
            "veggie", "meatless", "meat free", "vegetarien", "vegetarienne", "vegetariano", "vegetariana",
            "vegetarisch", "vegetarische", "ベジタリアン", "素食", "vegetariandiet",
        ], includes: ["Vegan"]),
        VocabularyTerm("Vegan", .diet, [
            "plant based", "vegane", "veganes", "vegetalien", "vegetalienne", "vegano", "vegana", "ヴィーガン",
            "ビーガン", "纯素", "vegandiet",
        ]),
        VocabularyTerm("Gluten-free", .diet, [
            "glutenfree", "gluten free", "no gluten", "sans gluten", "senza glutine", "sin gluten", "glutenfrei",
            "グルテンフリー", "无麸质", "glutenfreediet",
        ]),
        VocabularyTerm("Dairy-free", .diet, [
            "dairyfree", "dairy free", "no dairy", "non dairy", "lactose free", "sans lactose",
            "sans produits laitiers", "senza lattosio", "sin lactosa", "sin lacteos", "laktosefrei", "milchfrei",
            "乳製品不使用",
        ], includes: ["Vegan"]),
    ]

    // MARK: Traits

    static let traits: [VocabularyTerm] = [
        VocabularyTerm("High protein", .trait, [
            "protein", "high protein", "protein packed", "protein rich", "high in protein", "riche en proteines",
            "proteico", "proteica", "alto en proteinas", "rico en proteinas", "proteinreich", "eiweissreich",
            "高タンパク", "高たんぱく", "高蛋白",
        ]),
        VocabularyTerm("Light", .trait, [
            "low calorie", "low calories", "low cal", "lowcal", "lowcaloriediet", "leger", "legere", "leggero",
            "leggera", "ligero", "ligera", "kalorienarm", "低カロリー", "低卡",
        ]),
        VocabularyTerm("Quick", .trait, [
            "fast", "quick and easy", "15 minute", "15 minutes", "20 minute", "20 minutes", "30 minute",
            "30 minutes", "under 30 minutes", "rapide", "veloce", "rapido", "rapida", "schnell", "時短", "快手",
        ]),
    ]
}

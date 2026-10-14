const moreStrings = <String, Map<String, String>>{
  'en': {
    'aliases': 'Also known as',
    'alias': 'Alias',
    'addAlias': 'Add alias',
    'aliasHint': 'Nickname, maiden name, other spelling…',
    'aliasHelp':
        'Search finds this contact by any alias. Saved to the phone as its nickname.',
    'aliasOrderHelp':
        'Tap an alias to make it the first one, used for {alias} in messages.',
    'akaLine': 'aka {names}',
    'matchAlias': 'aka {alias}',
    'fld_aliases': 'Aliases',
    'includeAliases': 'Include aliases',
    'tok_alias': 'Alias',
    'grpAliases': 'Aliases',
    'opAddAlias': 'Add an alias',
    'opAddAliasSub': 'Give every selected contact the same alias',
    'opAddAliasHelp':
        'Separate several with commas. Names already used are skipped.',
    'opKeepAlias': 'Keep name as alias',
    'opKeepAliasSub':
        'Save the current name before renaming, so search still finds it',
    'opPromoteAlias': 'Use first alias as name',
    'opPromoteAliasSub': '“Dr. Mohammed” aka “Mo” → “Mo” aka “Dr. Mohammed”',
    'opClearAliases': 'Remove aliases',
    'opClearAliasesSub': 'Clear every alias from the selected contacts',
    'patternHelp':
        '{name} full name · {first} · {last} · {alias} · {company} · {n} running number',
    'getTemplate': 'Blank template',
    'getTemplateSub':
        'Excel or CSV with the exact columns the app reads. Fill it in, then import it',
    'issue_unreadable':
        'Could not read {name}. It may be damaged or not a contacts file. Use xlsx, csv, vcf, json or txt, or download a template below.',
    'issue_legacyExcel':
        '{name} is an old Excel (xls) file. Open it in Excel, save it as xlsx or csv, then import it again.',
    'issue_empty': '{name} is empty.',
    'issue_headerOnly':
        '{name} has the column headers but no contacts yet. Add one person per row and import it again.',
    'issue_noColumns':
        'No phone or email column found in {name}. Download a template below to see the columns the app expects.',
    'issue_noContacts':
        '{name} has no rows with a phone number or email. Compare it with the template below.',
    'tplSheet': 'Instructions',
    'tplContacts': 'Contacts',
    'tplTitle': 'How to fill this template',
    'tplColColumn': 'Column',
    'tplColMeaning': 'What to enter',
    'tplColExample': 'Example',
    'tplName': 'Full name of the person.',
    'tplPhone':
        'Main phone number with country code. Needed unless there is an email.',
    'tplPhone2':
        'Optional second number. You can add more phone columns the same way.',
    'tplEmail': 'Optional. Separate several addresses with a semicolon.',
    'tplCompany': 'Optional. Company or organisation.',
    'tplNote': 'Optional. Any free text.',
    'tplAlias': 'Optional. Other names for this person, separated by commas.',
    'tplExName': 'Sara Ahmed',
    'tplExPhone': '+14155550123',
    'tplExPhone2': '+14155550456',
    'tplExNote': 'Prefers WhatsApp',
    'tplExAlias': 'Sally, Dr. Sara',
    'tplTips': 'Tips',
    'tplTip1':
        'Fill the first sheet, one person per row, and keep the header row as it is.',
    'tplTip2':
        'Each row needs at least one phone number or email, otherwise it is skipped.',
    'tplTip3':
        'Write numbers with the country code (for example +20, +966, +86). Put several numbers in one cell separated by a semicolon.',
  },
  'ar': {
    'aliases': 'يُعرف أيضًا باسم',
    'alias': 'اسم بديل',
    'addAlias': 'إضافة اسم بديل',
    'aliasHint': 'لقب، كنية، تهجئة أخرى…',
    'aliasHelp':
        'يجد البحث هذه الجهة بأي اسم بديل. يُحفظ في الهاتف كاسم مستعار.',
    'aliasOrderHelp':
        'اضغط على اسم بديل لجعله الأول، ويُستخدم مكان {alias} في الرسائل.',
    'akaLine': 'ويُعرف بـ {names}',
    'matchAlias': 'يُعرف بـ {alias}',
    'fld_aliases': 'الأسماء البديلة',
    'includeAliases': 'تضمين الأسماء البديلة',
    'tok_alias': 'الاسم البديل',
    'grpAliases': 'الأسماء البديلة',
    'opAddAlias': 'إضافة اسم بديل',
    'opAddAliasSub': 'أضف الاسم البديل نفسه لكل الجهات المحددة',
    'opAddAliasHelp': 'افصل بين عدة أسماء بفواصل. تُتجاهل الأسماء المكرّرة.',
    'opKeepAlias': 'الاحتفاظ بالاسم كاسم بديل',
    'opKeepAliasSub': 'احفظ الاسم الحالي قبل إعادة التسمية ليبقى البحث يجده',
    'opPromoteAlias': 'استخدام أول اسم بديل كاسم',
    'opPromoteAliasSub':
        '«د. محمد» ويُعرف بـ «أبو أحمد» ← «أبو أحمد» ويُعرف بـ «د. محمد»',
    'opClearAliases': 'حذف الأسماء البديلة',
    'opClearAliasesSub': 'إزالة كل الأسماء البديلة من الجهات المحددة',
    'patternHelp':
        '{name} الاسم الكامل · {first} · {last} · {alias} · {company} · {n} رقم تسلسلي',
    'getTemplate': 'نموذج فارغ',
    'getTemplateSub':
        'ملف Excel أو CSV بالأعمدة التي يقرؤها التطبيق تمامًا. املأه ثم استورده',
    'issue_unreadable':
        'تعذّرت قراءة {name}. قد يكون الملف تالفًا أو ليس ملف جهات اتصال. استخدم xlsx أو csv أو vcf أو json أو txt، أو نزّل نموذجًا أدناه.',
    'issue_legacyExcel':
        '{name} ملف Excel قديم (xls). افتحه في Excel واحفظه بصيغة xlsx أو csv ثم استورده مجددًا.',
    'issue_empty': '{name} فارغ.',
    'issue_headerOnly':
        '{name} يحتوي على عناوين الأعمدة فقط ولا توجد جهات اتصال بعد. أضف شخصًا واحدًا في كل صف ثم استورده مجددًا.',
    'issue_noColumns':
        'لم يُعثر على عمود للهاتف أو البريد في {name}. نزّل نموذجًا أدناه لترى الأعمدة التي يتوقعها التطبيق.',
    'issue_noContacts':
        'لا توجد في {name} صفوف تحتوي على رقم هاتف أو بريد إلكتروني. قارنه بالنموذج أدناه.',
    'tplSheet': 'التعليمات',
    'tplContacts': 'جهات الاتصال',
    'tplTitle': 'كيفية تعبئة هذا النموذج',
    'tplColColumn': 'العمود',
    'tplColMeaning': 'ما يُكتب',
    'tplColExample': 'مثال',
    'tplName': 'الاسم الكامل للشخص.',
    'tplPhone':
        'رقم الهاتف الرئيسي مع رمز الدولة. مطلوب ما لم يوجد بريد إلكتروني.',
    'tplPhone2':
        'رقم ثانٍ اختياري. يمكنك إضافة أعمدة هاتف أخرى بالطريقة نفسها.',
    'tplEmail': 'اختياري. افصل بين عدة عناوين بفاصلة منقوطة.',
    'tplCompany': 'اختياري. الشركة أو الجهة.',
    'tplNote': 'اختياري. أي نص حر.',
    'tplAlias': 'اختياري. أسماء أخرى لهذا الشخص مفصولة بفواصل.',
    'tplExName': 'سارة أحمد',
    'tplExPhone': '+201001234567',
    'tplExPhone2': '+201201234567',
    'tplExNote': 'تفضّل واتساب',
    'tplExAlias': 'سالي، د. سارة',
    'tplTips': 'نصائح',
    'tplTip1':
        'املأ الورقة الأولى، شخصًا واحدًا في كل صف، واترك صف العناوين كما هو.',
    'tplTip2':
        'يحتاج كل صف إلى رقم هاتف أو بريد إلكتروني واحد على الأقل، وإلا يُتجاهل.',
    'tplTip3':
        'اكتب الأرقام مع رمز الدولة (مثل \u200E+20 و\u200E+966 و\u200E+86). ضع عدة أرقام في خلية واحدة وافصل بينها بفاصلة منقوطة.',
  },
  'zh': {
    'aliases': '别名',
    'alias': '别名',
    'addAlias': '添加别名',
    'aliasHint': '昵称、曾用名、其他写法…',
    'aliasHelp': '搜索任一别名都能找到此联系人。以昵称保存到手机。',
    'aliasOrderHelp': '点按别名可设为首个，消息中的 {alias} 将使用它。',
    'akaLine': '又名 {names}',
    'matchAlias': '又名 {alias}',
    'fld_aliases': '别名',
    'includeAliases': '包含别名',
    'tok_alias': '别名',
    'grpAliases': '别名',
    'opAddAlias': '添加别名',
    'opAddAliasSub': '为所选联系人添加相同的别名',
    'opAddAliasHelp': '多个别名用逗号分隔，已存在的会被跳过。',
    'opKeepAlias': '将姓名保留为别名',
    'opKeepAliasSub': '重命名前保存当前姓名，搜索仍能找到',
    'opPromoteAlias': '将首个别名设为姓名',
    'opPromoteAliasSub': '“王伟”又名“老王” → “老王”又名“王伟”',
    'opClearAliases': '移除别名',
    'opClearAliasesSub': '清除所选联系人的全部别名',
    'getTemplate': '空白模板',
    'getTemplateSub': '包含应用可识别列的 Excel 或 CSV，填写后导入',
    'issue_unreadable':
        '无法读取 {name}。文件可能已损坏，或不是联系人文件。请使用 xlsx、csv、vcf、json 或 txt，或在下方下载模板。',
    'issue_legacyExcel':
        '{name} 是旧版 Excel（xls）文件。请在 Excel 中另存为 xlsx 或 csv 后再导入。',
    'issue_empty': '{name} 是空文件。',
    'issue_headerOnly': '{name} 只有列标题，还没有联系人。请每行添加一个人后再导入。',
    'issue_noColumns': '在 {name} 中没有找到电话或邮箱列。请在下方下载模板，查看应用需要的列。',
    'issue_noContacts': '{name} 中没有包含电话或邮箱的行。请对照下方模板检查。',
    'tplSheet': '说明',
    'tplContacts': '联系人',
    'tplTitle': '如何填写此模板',
    'tplColColumn': '列',
    'tplColMeaning': '填写内容',
    'tplColExample': '示例',
    'tplName': '此人的全名。',
    'tplPhone': '主要电话号码，需包含国家/地区区号。没有邮箱时必填。',
    'tplPhone2': '可选的第二个号码。需要时可用同样方式添加更多电话列。',
    'tplEmail': '可选。多个邮箱请用分号分隔。',
    'tplCompany': '可选。公司或单位。',
    'tplNote': '可选。任意文字。',
    'tplAlias': '可选。此人的其他名字，用逗号分隔。',
    'tplExName': '王伟',
    'tplExPhone': '+8613800138000',
    'tplExPhone2': '+8613900139000',
    'tplExNote': '喜欢用微信',
    'tplExAlias': '小王，王经理',
    'tplTips': '提示',
    'tplTip1': '请填写第一个工作表，每行一个人，并保持标题行不变。',
    'tplTip2': '每行至少需要一个电话号码或邮箱，否则会被跳过。',
    'tplTip3': '号码请带国家/地区区号（如 +86、+20、+966）。同一单元格内的多个号码请用分号分隔。',
  },
  'es': {
    'aliases': 'También conocido como',
    'alias': 'Alias',
    'addAlias': 'Añadir alias',
    'aliasHint': 'Apodo, apellido de soltera, otra grafía…',
    'aliasHelp':
        'La búsqueda encuentra este contacto por cualquier alias. Se guarda en el teléfono como apodo.',
    'aliasOrderHelp':
        'Toca un alias para ponerlo primero; se usa para {alias} en los mensajes.',
    'akaLine': 'alias {names}',
    'matchAlias': 'alias {alias}',
    'fld_aliases': 'Alias',
    'includeAliases': 'Incluir alias',
    'tok_alias': 'Alias',
    'grpAliases': 'Alias',
    'opAddAlias': 'Añadir un alias',
    'opAddAliasSub': 'El mismo alias para todos los contactos seleccionados',
    'opAddAliasHelp': 'Separa varios con comas. Los repetidos se omiten.',
    'opKeepAlias': 'Guardar nombre como alias',
    'opKeepAliasSub': 'Conserva el nombre actual antes de renombrar',
    'opPromoteAlias': 'Usar el primer alias como nombre',
    'opPromoteAliasSub':
        '“José Álvarez” alias “Pepe” → “Pepe” alias “José Álvarez”',
    'opClearAliases': 'Quitar alias',
    'opClearAliasesSub': 'Borra todos los alias de los contactos seleccionados',
    'getTemplate': 'Plantilla en blanco',
    'getTemplateSub':
        'Excel o CSV con las columnas exactas que lee la app. Rellénala e impórtala',
    'issue_unreadable':
        'No se pudo leer {name}. Puede estar dañado o no ser un archivo de contactos. Usa xlsx, csv, vcf, json o txt, o descarga una plantilla abajo.',
    'issue_legacyExcel':
        '{name} es un archivo antiguo de Excel (xls). Ábrelo en Excel, guárdalo como xlsx o csv e impórtalo de nuevo.',
    'issue_empty': '{name} está vacío.',
    'issue_headerOnly':
        '{name} solo tiene los encabezados, aún sin contactos. Añade una persona por fila e impórtalo de nuevo.',
    'issue_noColumns':
        'No hay columna de teléfono ni de correo en {name}. Descarga una plantilla abajo para ver las columnas que espera la app.',
    'issue_noContacts':
        '{name} no tiene filas con teléfono ni correo. Compáralo con la plantilla de abajo.',
    'tplSheet': 'Instrucciones',
    'tplContacts': 'Contactos',
    'tplTitle': 'Cómo rellenar esta plantilla',
    'tplColColumn': 'Columna',
    'tplColMeaning': 'Qué escribir',
    'tplColExample': 'Ejemplo',
    'tplName': 'Nombre completo de la persona.',
    'tplPhone':
        'Teléfono principal con prefijo del país. Obligatorio si no hay correo.',
    'tplPhone2':
        'Segundo número, opcional. Puedes añadir más columnas de teléfono de la misma forma.',
    'tplEmail': 'Opcional. Separa varias direcciones con punto y coma.',
    'tplCompany': 'Opcional. Empresa u organización.',
    'tplNote': 'Opcional. Cualquier texto.',
    'tplAlias': 'Opcional. Otros nombres de esta persona, separados por comas.',
    'tplExName': 'Sara Pérez',
    'tplExPhone': '+34612345678',
    'tplExPhone2': '+34698765432',
    'tplExNote': 'Prefiere WhatsApp',
    'tplExAlias': 'Sally, Dra. Sara',
    'tplTips': 'Consejos',
    'tplTip1':
        'Rellena la primera hoja, una persona por fila, y deja la fila de encabezados como está.',
    'tplTip2':
        'Cada fila necesita al menos un teléfono o un correo; si no, se omite.',
    'tplTip3':
        'Escribe los números con el prefijo del país (por ejemplo +34, +52, +20). Varios números en una celda: sepáralos con punto y coma.',
  },
  'fr': {
    'aliases': 'Aussi appelé',
    'alias': 'Alias',
    'addAlias': 'Ajouter un alias',
    'aliasHint': 'Surnom, nom de jeune fille, autre orthographe…',
    'aliasHelp':
        'La recherche trouve ce contact par n’importe quel alias. Enregistré sur le téléphone comme surnom.',
    'aliasOrderHelp':
        'Touchez un alias pour le placer en premier ; il remplace {alias} dans les messages.',
    'akaLine': 'alias {names}',
    'matchAlias': 'alias {alias}',
    'fld_aliases': 'Alias',
    'includeAliases': 'Inclure les alias',
    'tok_alias': 'Alias',
    'grpAliases': 'Alias',
    'opAddAlias': 'Ajouter un alias',
    'opAddAliasSub': 'Le même alias pour tous les contacts sélectionnés',
    'opAddAliasHelp':
        'Séparez-en plusieurs par des virgules. Les doublons sont ignorés.',
    'opKeepAlias': 'Garder le nom comme alias',
    'opKeepAliasSub': 'Conserve le nom actuel avant de renommer',
    'opPromoteAlias': 'Utiliser le premier alias comme nom',
    'opPromoteAliasSub':
        '« Léa Fontaine » alias « Lili » → « Lili » alias « Léa Fontaine »',
    'opClearAliases': 'Retirer les alias',
    'opClearAliasesSub': 'Efface tous les alias des contacts sélectionnés',
    'getTemplate': 'Modèle vierge',
    'getTemplateSub':
        'Excel ou CSV avec les colonnes exactes lues par l’app. Remplissez-le puis importez-le',
    'issue_unreadable':
        'Impossible de lire {name}. Il est peut-être endommagé ou ce n’est pas un fichier de contacts. Utilisez xlsx, csv, vcf, json ou txt, ou téléchargez un modèle ci-dessous.',
    'issue_legacyExcel':
        '{name} est un ancien fichier Excel (xls). Ouvrez-le dans Excel, enregistrez-le en xlsx ou csv, puis réimportez-le.',
    'issue_empty': '{name} est vide.',
    'issue_headerOnly':
        '{name} ne contient que les en-têtes, pas encore de contacts. Ajoutez une personne par ligne puis réimportez.',
    'issue_noColumns':
        'Aucune colonne de téléphone ou d’e-mail dans {name}. Téléchargez un modèle ci-dessous pour voir les colonnes attendues.',
    'issue_noContacts':
        '{name} n’a aucune ligne avec un numéro ou un e-mail. Comparez-le au modèle ci-dessous.',
    'tplSheet': 'Instructions',
    'tplContacts': 'Contacts',
    'tplTitle': 'Comment remplir ce modèle',
    'tplColColumn': 'Colonne',
    'tplColMeaning': 'Quoi saisir',
    'tplColExample': 'Exemple',
    'tplName': 'Nom complet de la personne.',
    'tplPhone':
        'Numéro principal avec l’indicatif du pays. Obligatoire s’il n’y a pas d’e-mail.',
    'tplPhone2':
        'Deuxième numéro, facultatif. Vous pouvez ajouter d’autres colonnes de téléphone de la même façon.',
    'tplEmail': 'Facultatif. Séparez plusieurs adresses par un point-virgule.',
    'tplCompany': 'Facultatif. Société ou organisation.',
    'tplNote': 'Facultatif. Texte libre.',
    'tplAlias':
        'Facultatif. Autres noms de cette personne, séparés par des virgules.',
    'tplExName': 'Sara Martin',
    'tplExPhone': '+33612345678',
    'tplExPhone2': '+33698765432',
    'tplExNote': 'Préfère WhatsApp',
    'tplExAlias': 'Sally, Dr Sara',
    'tplTips': 'Conseils',
    'tplTip1':
        'Remplissez la première feuille, une personne par ligne, et laissez la ligne d’en-têtes telle quelle.',
    'tplTip2':
        'Chaque ligne doit avoir au moins un numéro ou un e-mail, sinon elle est ignorée.',
    'tplTip3':
        'Écrivez les numéros avec l’indicatif du pays (par exemple +33, +212, +20). Plusieurs numéros dans une cellule : séparez-les par un point-virgule.',
  },
};

unit WebModuleUnit1;

interface

uses
  System.SysUtils, System.Classes, Web.HTTPApp, Data.DB, Data.Win.ADODB, System.Hash, System.DateUtils;

type
  TWebModule1 = class(TWebModule)
    ADOConnection1: TADOConnection;
    ADOQuery1: TADOQuery;
    procedure WebModule1DefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1LoginActionAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1RegisterActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1CreateActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1ExitActionAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1DeleteActionAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebModule1EditActionAction(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}



// ---------- ФУНКЦИИ ----------



// --- Экранирование ---
function HtmlEncode(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '&',  '&amp;',  [rfReplaceAll]);
  Result := StringReplace(Result, '<',  '&lt;',   [rfReplaceAll]);
  Result := StringReplace(Result, '>',  '&gt;',   [rfReplaceAll]);
  Result := StringReplace(Result, '"',  '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&#39;',  [rfReplaceAll]);
end;
// --- Перенаправление на другую страницу ---
procedure RedirectTo(Response: TWebResponse; const URL: string);
begin
  Response.StatusCode := 302;
  Response.SetCustomHeader('Location', URL);
  Response.Content := '';
end;
// --- Проверка сессии и вывод user_id ---
function getUserId(Request: TWebRequest; AQuery: TADOQuery): Integer;
var
  Token: string;
begin
  Result := 0;

  Token := Request.CookieFields.Values['session_token'];
  if Token = '' then
    Exit;

  AQuery.Close;
  AQuery.SQL.Clear;
  AQuery.Parameters.Clear;

  AQuery.SQL.Text := 'SELECT user_id FROM Sessions WHERE session_token = :token AND expires_at > :now';
  AQuery.Parameters.ParamByName('token').Value := Token;
  AQuery.Parameters.ParamByName('now').Value := Now;
  AQuery.Open;

  try
    if not AQuery.IsEmpty then
      Result := AQuery.FieldByName('user_id').AsInteger;
  finally
    AQuery.Close;
  end;

end;
// --- Шапка сайта ---
function renderHeader: string;
begin
  Result :=
  '<header class="header">' +
    '<div class="header-left">' +
      '<div class="header-left__logo">Задачник</div>' +
      '<nav class="header-left__nav">' +
        '<a href="/Project1.dll/">Мои задачи</a>' +
        '<a href="/Project1.dll/create">Создать задачу</a>' +
      '</nav>' +
    '</div>' +
    '<a href="/Project1.dll/exit" class="profile-exit">Выйти</a>' +
  '</header>';
end;





// ---------- СТРАНИЦЫ ----------



// --- СОЗДАТЬ ЗАДАЧУ ---
procedure TWebModule1.WebModule1CreateActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  // --- сессия авторизации ---
  userId: Integer;

  // --- данные формы ---
  formTitle: string;
  formDescription: string;
  dueDateStr: string; // Строка из формы
  dueDate: TDateTime; // Распарсеная дата-время

  // --- ошибки ---
  errorMessage: string;
  errorCode: string;
begin
  errorMessage := '';
  errorCode := '';

  formTitle := '';
  formDescription := '';
  dueDateStr := '';

  // --- Проверка: пользователь авторизован? ---
  userId := getUserId(Request, ADOQuery1);

  if userId = 0 then
  begin
    RedirectTo(Response, '/Project1.dll/login');
    Exit;
  end;



  // --- Код ---
  if Request.Method = 'POST' then
  begin
    // --- Получение данных ---
    formTitle := Trim(Request.ContentFields.Values['title']);
    formDescription := Trim(Request.ContentFields.Values['description']);
    dueDateStr := Request.ContentFields.Values['due_date'];


    // --- Проверка текста задачи ---
    if formTitle = '' then
      errorMessage := 'Введите название задачи'
    else if Length(formTitle) > 100 then
      errorMessage := 'Название слишком длинное (макс. 100)'
    else if formDescription = '' then
      errorMessage := 'Введите описание'
    else if Length(formDescription) > 500 then
      errorMessage := 'Описание слишком длинное (макс. 500)'
    else if dueDateStr = '' then
      errorMessage := 'Укажите дату и время выполнения';


    // --- Парсинг ---
    if errorMessage = '' then
    begin
      try
        dueDate := EncodeDateTime(
          StrToInt(Copy(dueDateStr, 1, 4)),    // год
          StrToInt(Copy(dueDateStr, 6, 2)),    // месяц
          StrToInt(Copy(dueDateStr, 9, 2)),    // день
          StrToInt(Copy(dueDateStr, 12, 2)),   // час
          StrToInt(Copy(dueDateStr, 15, 2)),   // минута
          0, 0
        );
        if dueDate <= Now then
          errorMessage := 'Дата должна быть в будущем';
      except
        errorMessage := 'Неверный формат даты';
      end;
    end;


    // --- Запись в БД ---
    if errorMessage = '' then
    begin
      ADOQuery1.Close;
      ADOQuery1.SQL.Clear;
      ADOQuery1.Parameters.Clear;

      ADOQuery1.SQL.Text :=
        'INSERT INTO Tasks (user_id, title, description, created_at, due_datetime) ' +
        'VALUES (:user_id, :title, :description, :created_at, :due_datetime)';

      ADOQuery1.Parameters.ParamByName('user_id').Value := userId;
      ADOQuery1.Parameters.ParamByName('title').Value := formTitle;
      ADOQuery1.Parameters.ParamByName('description').Value := formDescription;
      ADOQuery1.Parameters.ParamByName('created_at').Value := Now;
      ADOQuery1.Parameters.ParamByName('due_datetime').Value := FormatDateTime('yyyy-mm-dd hh:nn:ss', dueDate);

      ADOQuery1.ExecSQL;

      RedirectTo(Response, '/Project1.dll/');
      Exit;
    end;
  end;


  if errorMessage <> '' then
    errorCode := '<div class="create-task__error">' + HtmlEncode(errorMessage) + '</div>';


  // --- Ответ ---
  Response.Content :=
  '<html>' +
    '<head>' +
      '<title>Задачник - Создать задачу</title>' +
      '<link rel="stylesheet" href="/css/style.css">' +
      '<link rel="stylesheet" href="/css/header.css">' +
      '<link rel="stylesheet" href="/css/create_task.css">' +
    '</head>' +
    '<body>' +
      renderHeader +
      '<div class="container">' +
        '<form class="create-task" method="POST" action="/Project1.dll/create">' +
          '<h1>Создать задачу</h1>' +
          errorCode +
          '<div class="create-task__field">' +
            '<label class="create-task__label" for="title">Название:</label>' +
            '<input type="text" class="create-task__title" id="title" name="title" value="' + HtmlEncode(formTitle) + '" maxlength="100" required>' +
          '</div>' +
          '<div class="create-task__field">' +
            '<label class="create-task__label" for="description">Описание:</label>' +
            '<textarea class="create-task__description" id="description" name="description" maxlength="500" required>' + HtmlEncode(formDescription) + '</textarea>' +
          '</div>' +
          '<div class="create-task__field">' +
            '<label class="create-task__label" for="due_date">Выполнить до:</label>' +
            '<input type="datetime-local" min="' + FormatDateTime('yyyy-mm-dd"T"hh:nn', Now) + '" class="create-task__calendar" id="due_date" name="due_date" value="' + HtmlEncode(dueDateStr) + '" required>' +
          '</div>' +
          '<input type="submit" class="create-task__submit" value="Создать">' +
        '</form>' +
      '</div>' +
    '</body>' +
  '</html>';
end;





// --- ГЛАВНАЯ СТРАНИЦА ---
procedure TWebModule1.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  // --- ID пользователя ---
  userId: Integer;

  // --- Данные задач ---
  tasksHtml: string;
  taskId: Integer;
  taskTitle: string;
  taskDescription: string;
  taskDueDate: TDateTime;
begin
  tasksHtml := '';

  // --- Проверка: пользователь авторизован? ---
  userId := getUserId(Request, ADOQuery1);

  if userId = 0 then
  begin
    RedirectTo(Response, '/Project1.dll/login');
    Exit;
  end;



  // --- Код ---
  ADOQuery1.Close;
  ADOQuery1.SQL.Clear;
  ADOQuery1.Parameters.Clear;

  ADOQuery1.SQL.Text :=
    'SELECT id, title, description, due_datetime FROM Tasks ' +
    'WHERE user_id = :user_id AND due_datetime > :now ' +
    'ORDER BY due_datetime ASC';
  ADOQuery1.Parameters.ParamByName('user_id').Value := userId;
  ADOQuery1.Parameters.ParamByName('now').Value := Now;
  ADOQuery1.Open;


  // --- Цикл перебора задач ---
  try
    while not ADOQuery1.Eof do
    begin
      taskId := ADOQuery1.FieldByName('id').AsInteger;
      taskTitle := ADOQuery1.FieldByName('title').AsString;
      taskDescription := ADOQuery1.FieldByName('description').AsString;
      taskDueDate := ADOQuery1.FieldByName('due_datetime').AsDateTime;


      tasksHtml := tasksHtml +
      '<article class="task">' +
        '<h2 class="task-title">' + HtmlEncode(taskTitle) + '</h2>' +
        '<div class="task-description">' + HtmlEncode(taskDescription) + '</div>' +
        '<div class="task-datetime">Выполнить до: ' + FormatDateTime('dd.mm.yyyy "в" hh:nn', taskDueDate) + '</div>'+
        '<footer class="task-footer">' +
          '<a href="/Project1.dll/edit?id=' + IntToStr(taskId) + '" class="task-footer__button">Изменить</a>' +
          '<a href="/Project1.dll/delete?id=' + IntToStr(taskId) + '" class="task-footer__button">Удалить</a>' +
        '</footer>' +
      '</article>';

      ADOQuery1.Next;
    end;
  finally
    ADOQuery1.Close;
  end;



  if tasksHtml = '' then
    tasksHtml := '<div class="tasks-empty">Нет активных задач</div>';


  Response.Content :=
  '<html>' +
    '<head>' +
      '<title>Мои задачи</title>' +
      '<link rel="stylesheet" href="/css/style.css">' +
      '<link rel="stylesheet" href="/css/header.css">' +
      '<link rel="stylesheet" href="/css/tasks.css">' +
    '</head>' +
    '<body>' +
      renderHeader +
      '<div class="container">' +
        '<div class="content">' +
          tasksHtml +
        '</div>' +
      '</div>' +
    '</body>' +
  '</html>';
end;





// --- УДАЛИТЬ ЗАДАЧУ ---
procedure TWebModule1.WebModule1DeleteActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  userId: Integer;
  taskId: Integer;
begin

  // --- Проверка: пользователь авторизован? ---
  userId := getUserId(Request, ADOQuery1);

  if userId = 0 then
  begin
    RedirectTo(Response, '/Project1.dll/login');
    Exit;
  end;


  taskId := StrToIntDef(Request.QueryFields.Values['id'], 0);
  if taskId = 0 then
  begin
    RedirectTo(Response, '/Project1.dll/');
    Exit;
  end;


  ADOQuery1.Close;
  ADOQuery1.SQL.Clear;
  ADOQuery1.Parameters.Clear;

  ADOQuery1.SQL.Text := 'DELETE FROM Tasks WHERE id = :id AND user_id = :user_id';
  ADOQuery1.Parameters.ParamByName('id').Value := taskId;
  ADOQuery1.Parameters.ParamByName('user_id').Value := userId;
  ADOQuery1.ExecSQL;

  RedirectTo(Response, '/Project1.dll/');
end;






// --- РЕДАКТИРОВАТЬ ЗАДАЧУ ---
procedure TWebModule1.WebModule1EditActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  // --- Пользовательский ID ---
  userId: Integer;

  // --- Данные задачи ---
  taskId: Integer;

  formTitle: string;
  formDescription: string;
  dueDateStr: string;
  dueDate: TDateTime;

  // --- Вывод оповещения ---
  errorMessage: string;
  errorCode: string;

begin
  errorMessage := '';
  errorCode := '';

  formTitle := '';
  formDescription := '';
  dueDateStr := '';

  // --- Проверка: пользователь авторизован? ---
  userId := getUserId(Request, ADOQuery1);

  if userId = 0 then
  begin
    RedirectTo(Response, '/Project1.dll/login');
    Exit;
  end;


  // --- Получение ID задачи ---
  taskId := StrToIntDef(Request.QueryFields.Values['id'], 0);
  if taskId = 0 then
  begin
    RedirectTo(Response, '/Project1.dll/');
    Exit;
  end;


  // --- Код ---
  if Request.Method = 'POST' then
  begin
    // --- Получение данных ---
    formTitle := Trim(Request.ContentFields.Values['title']);
    formDescription := Trim(Request.ContentFields.Values['description']);
    dueDateStr := Request.ContentFields.Values['due_date'];


    // --- Проверка текста задачи ---
    if formTitle = '' then
      errorMessage := 'Введите название задачи'
    else if Length(formTitle) > 100 then
      errorMessage := 'Название слишком длинное (макс. 100)'
    else if formDescription = '' then
      errorMessage := 'Введите описание'
    else if Length(formDescription) > 500 then
      errorMessage := 'Описание слишком длинное (макс. 500)'
    else if dueDateStr = '' then
      errorMessage := 'Укажите дату и время выполнения';


    // --- Парсинг ---
    if errorMessage = '' then
    begin
      try
        dueDate := EncodeDateTime(
          StrToInt(Copy(dueDateStr, 1, 4)),    // год
          StrToInt(Copy(dueDateStr, 6, 2)),    // месяц
          StrToInt(Copy(dueDateStr, 9, 2)),    // день
          StrToInt(Copy(dueDateStr, 12, 2)),   // час
          StrToInt(Copy(dueDateStr, 15, 2)),   // минута
          0, 0
        );
        if dueDate <= Now then
          errorMessage := 'Дата должна быть в будущем';
      except
        errorMessage := 'Неверный формат даты';
      end;
    end;


    // --- Обновление данных ---
    if errorMessage = '' then
    begin
      ADOQuery1.Close;
      ADOQuery1.SQL.Clear;
      ADOQuery1.Parameters.Clear;

      ADOQuery1.SQL.Text := 'UPDATE Tasks SET title = :title, description = :description, due_datetime = :due_datetime WHERE id = :id AND user_id = :user_id';
      ADOQuery1.Parameters.ParamByName('title').Value := formTitle;
      ADOQuery1.Parameters.ParamByName('description').Value := formDescription;
      ADOQuery1.Parameters.ParamByName('due_datetime').Value := FormatDateTime('yyyy-mm-dd hh:nn:ss', dueDate);
      ADOQuery1.Parameters.ParamByName('id').Value := taskId;
      ADOQuery1.Parameters.ParamByName('user_id').Value := userId;

      ADOQuery1.ExecSQL;

      RedirectTo(Response, '/Project1.dll/');
      Exit;
    end;
  end
  else
  begin
    ADOQuery1.Close;
    ADOQuery1.SQL.Clear;
    ADOQuery1.Parameters.Clear;

    ADOQuery1.SQL.Text := 'SELECT title, description, due_datetime FROM Tasks WHERE id = :id AND user_id = :user_id';
    ADOQuery1.Parameters.ParamByName('id').Value := taskId;
    ADOQuery1.Parameters.ParamByName('user_id').Value := userId;
    ADOQuery1.Open;

    // --- Если такого пользователя нет ---
    if ADOQuery1.IsEmpty then
    begin
      ADOQuery1.Close;
      RedirectTo(Response, '/Project1.dll/');
      Exit;
    end;

    // --- Данные с задачи ---
    formTitle := ADOQuery1.FieldByName('title').AsString;
    formDescription := ADOQuery1.FieldByName('description').AsString;
    dueDateStr := FormatDateTime('yyyy-mm-dd"T"hh:nn', ADOQuery1.FieldByName('due_datetime').AsDateTime);
    ADOQuery1.Close;
  end;


  if errorMessage <> '' then
    errorCode := '<div class="update-task__error">' + HtmlEncode(errorMessage) + '</div>';


  Response.Content :=
  '<html>' +
    '<head>' +
      '<title>Задачник - Редактировать задачу</title>' +
      '<link rel="stylesheet" href="/css/style.css">' +
      '<link rel="stylesheet" href="/css/header.css">' +
      '<link rel="stylesheet" href="/css/edit.css">' +
    '</head>' +
    '<body>' +
      renderHeader +
      '<div class="container">' +
        '<form class="update-task" method="POST" action="/Project1.dll/edit?id=' + IntToStr(taskId) + '">' +
          '<h1>Редактировать задачу</h1>' +
          errorCode +
          '<div class="update-task__field">' +
            '<label class="update-task__label" for="title">Название:</label>' +
            '<input type="text" class="update-task__title" id="title" name="title" maxlength="100" value="' + HtmlEncode(formTitle) + '" required>' +
          '</div>' +
          '<div class="update-task__field">' +
            '<label class="update-task__label" for="description">Описание:</label>' +
            '<textarea class="update-task__description" id="description" name="description" maxlength="500" required>' + HtmlEncode(formDescription) + '</textarea>' +
          '</div>' +
          '<div class="update-task__field">' +
            '<label class="update-task__label" for="due_date">Выполнить до:</label>' +
            '<input type="datetime-local" min="' + FormatDateTime('yyyy-mm-dd"T"hh:nn', Now) + '" class="update-task__calendar" id="due_date" name="due_date" value="' + HtmlEncode(dueDateStr) + '" required>' +
          '</div>' +
          '<input type="submit" class="update-task__submit" value="Сохранить">' +
        '</form>' +
      '</div>' +
    '</body>' +
  '</html>';
end;





// --- ВЫХОД ИЗ АККАУНТА ---
procedure TWebModule1.WebModule1ExitActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  sessionToken: string;
  cookies: TStringList;
begin
  // --- Получаем токен ---
  sessionToken := Request.CookieFields.Values['session_token'];


  if sessionToken <> '' then
  begin
    ADOQuery1.Close;
    ADOQuery1.SQL.Clear;
    ADOQuery1.Parameters.Clear;

    ADOQuery1.SQL.Text := 'DELETE FROM Sessions WHERE session_token = :token';
    ADOQuery1.Parameters.ParamByName('token').Value := sessionToken;
    ADOQuery1.ExecSQL;
  end;


  // --- Стираем cookie ---
  cookies := TStringList.Create;
  try
    cookies.Add('session_token=');
    Response.SetCookieField(cookies, '', '/', EncodeDate(1970, 1, 1), False, True, 'Lax');
  finally
    cookies.Free;
  end;

  // --- Редирект на логин ---
  RedirectTo(Response, '/Project1.dll/login');
end;







// --- АВТОРИЗАЦИЯ ---
procedure TWebModule1.WebModule1LoginActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  // --- Данные из формы ---
  formLogin: string;
  formPassword: string;

  // --- Для проверки паролей ---
  passwordHash: string;
  dbPasswordHash: string;

  // --- Проверка ошибок ---
  errorMessage: string;
  errorCode: string;

  // --- Пользовательский ID ---
  userId: Integer;

  // --- Сессия ---
  sessionToken: string;
  expiresDate: TDateTime;

  // --- Куки ---
  cookies: TStringList;
begin
  errorMessage := '';
  errorCode := '';

  formLogin := '';
  formPassword := '';

  // --- Проверка: пользователь авторизован? ---
  userId := getUserId(Request, ADOQuery1);

  if userId <> 0 then
  begin
    RedirectTo(Response, '/Project1.dll/');
    Exit;
  end;



  // --- КОД ---
  if Request.Method = 'POST' then
  begin
    // --- Получение данных ---
    formLogin := Request.ContentFields.Values['login'];
    formPassword := Request.ContentFields.Values['password'];


    // --- Проверка логина и пароля на пустоту ---
    if (formLogin = '') or (formPassword = '') then
      errorMessage := 'Неверный логин или пароль';


    // --- Вывод данных пользователя ---
    if errorMessage = '' then
    begin
      ADOQuery1.Close;
      ADOQuery1.SQL.Clear;
      ADOQuery1.Parameters.Clear;

      ADOQuery1.SQL.Text := 'SELECT id, password_hash FROM Users WHERE login = :login';
      ADOQuery1.Parameters.ParamByName('login').Value := formLogin;
      ADOQuery1.Open;

      // --- Если такого пользователя нет ---
      if ADOQuery1.isEmpty then
      begin
        errorMessage := 'Неверный логин или пароль';
        ADOQuery1.Close;
      end
      else
      begin
        userId := ADOQuery1.FieldByName('id').AsInteger;
        dbPasswordHash := ADOQuery1.FieldByName('password_hash').AsString;

        ADOQuery1.Close;

        // --- Проверка паролей на совпадение ---
        passwordHash := THashSHA2.GetHashString(formPassword);

        if passwordHash <> dbPasswordHash then
          errorMessage := 'Неверный логин или пароль'
        else
        begin
          ADOQuery1.SQL.Clear;
          ADOQuery1.Parameters.Clear;

          ADOQuery1.SQL.Text := 'DELETE FROM Sessions WHERE user_id = :user_id';
          ADOQuery1.Parameters.ParamByName('user_id').Value := userId;
          ADOQuery1.ExecSQL;


          // --- Создание сессии ---
          sessionToken := THashSHA2.GetHashString(TGUID.NewGuid.ToString);
          expiresDate := Now + EncodeTime(1, 0, 0, 0);


          // --- Запись сессии в БД ---
          ADOQuery1.SQL.Clear;
          ADOQuery1.Parameters.Clear;

          ADOQuery1.SQL.Text := 'INSERT INTO Sessions (user_id, session_token, expires_at) VALUES (:user_id, :session_token, :expires_at)';
          ADOQuery1.Parameters.ParamByName('user_id').Value := userId;
          ADOQuery1.Parameters.ParamByName('session_token').Value := sessionToken;
          ADOQuery1.Parameters.ParamByName('expires_at').Value := expiresDate;
          ADOQuery1.ExecSQL;

          // --- Создание Cookie сессии ---
          cookies := TStringList.Create;
          try
            cookies.Add('session_token=' + sessionToken);
            Response.SetCookieField(cookies, '', '/', expiresDate, False, True, 'Lax');
          finally
            cookies.Free;
          end;

          // --- Ручное перенаправление на главную ---
          RedirectTo(Response, '/Project1.dll/');
          Exit;
        end;
      end;
    end;
  end;


  if errorMessage <> '' then
    errorCode := '<div class="authorization-error">' + HtmlEncode(errorMessage) + '</div>';


  Response.Content :=
  '<html>' +
    '<head>' +
      '<title>Авторизация</title>' +
      '<link rel="stylesheet" href="/css/style.css">' +
      '<link rel="stylesheet" href="/css/authorization.css">' +
    '</head>' +
    '<body>' +
      '<div class="container">' +
        '<form class="authorization" method="POST" action="/Project1.dll/login">' +
          '<h1>Авторизация</h1>' +
          errorCode +
          '<input type="text" class="authorization-input" name="login" value="' + HtmlEncode(formLogin) + '" placeholder="Введите логин">' +
          '<input type="password" class="authorization-input" name="password" placeholder="Введите пароль">' +
          '<input type="submit" class="authorization-submit" value="Войти">' +
          '<a href="/Project1.dll/register" class="authorization-link">Нет аккаунта? Зарегистрируйтесь</a>' +
        '</form>' +
      '</div>' +
    '</body>' +
  '</html>';
end;








// --- РЕГИСТРАЦИЯ ---
procedure TWebModule1.WebModule1RegisterActionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  // --- Данные из формы ---
  formLogin: string;
  formPassword: string;
  formPasswordRepeat: string;

  // --- Для проверки существования пользователя с таким логином ---
  userCount: Integer;

  // --- Хеш пароля ---
  passwordHash: string;

  // --- Проверка ошибок ---
  errorMessage: string;
  errorCode: string;

  // --- ID пользователя ---
  userId: Integer;
begin
  errorMessage := '';
  errorCode := '';

  formLogin := '';
  formPassword := '';

  // --- Проверка: пользователь авторизован? ---
  userId := getUserId(Request, ADOQuery1);

  if userId <> 0 then
  begin
    RedirectTo(Response, '/Project1.dll/');
    Exit;
  end;



  // --- КОД ---
  if Request.Method = 'POST' then
  begin
    // --- Данные из формы ---
    formLogin := Trim(Request.ContentFields.Values['login']);
    formPassword := Request.ContentFields.Values['password'];
    formPasswordRepeat := Request.ContentFields.Values['passwordRepeat'];

    // --- Проверка логина на пустоту ---
    if formLogin = '' then
      errorMessage := 'Вы не ввели логин'
    else if Length(formLogin) > 15 then
      errorMessage := 'Слишком длинный логин (макс. 15)'
    else if formPassword = '' then
      errorMessage := 'Вы не ввели пароль'
    else if Length(formPassword) < 6 then
      errorMessage := 'Слишком короткий пароль (мин. 6)'
    else if Length(formPassword) > 128 then
      errorMessage := 'Слишком длинный пароль (макс. 128)'
    else if formPassword <> formPasswordRepeat  then
      errorMessage := 'Пароли не совпадают';


    // --- Проверка логина в БД ---
    if errorMessage = '' then
    begin
      ADOQuery1.Close;
      ADOQuery1.SQL.Clear;
      ADOQuery1.Parameters.Clear;

      ADOQuery1.SQL.Text := 'SELECT COUNT(*) FROM Users WHERE login = :login';
      ADOQuery1.Parameters.ParamByName('login').Value := formLogin;
      ADOQuery1.Open;

      userCount := ADOQuery1.Fields[0].AsInteger;

      ADOQuery1.Close;

      if userCount > 0 then
        errorMessage := 'Такой пользователь уже существует'
      else
      begin
        // --- Хеширование пароля для безопасности ---
        passwordHash := THashSHA2.GetHashString(formPassword);

        // --- Регистрация пользователя ---
        ADOQuery1.Close;
        ADOQuery1.SQL.Clear;
        ADOQuery1.Parameters.Clear;

        ADOQuery1.SQL.Text := 'INSERT INTO Users (login, password_hash) VALUES (:login, :password_hash)';
        ADOQuery1.Parameters.ParamByName('login').Value := formLogin;
        ADOQuery1.Parameters.ParamByName('password_hash').Value := passwordHash;
        ADOQuery1.ExecSQL;

        Response.Content :=
        '<html>' +
          '<head>' +
            '<title>Задачник - Регистрация</title>' +
            '<link rel="stylesheet" href="/css/style.css">' +
            '<link rel="stylesheet" href="/css/register.css">' +
          '</head>' +
          '<body>' +
            '<div class="container">' +
              '<div class="register-alert">' +
                '<div class="register-alert__title">Вы успешно зарегистрированы</div>' +
                '<a href="/Project1.dll/login" class="register-alert__link">Авторизоваться</a>' +
              '</div>' +
            '</div>' +
          '</body>' +
        '</html>';
        Exit;
      end;
    end;
  end;

  if errorMessage <> '' then
    errorCode := '<div class="register-error">' + HtmlEncode(errorMessage) + '</div>';

  Response.Content :=
  '<html>' +
    '<head>' +
      '<title>Задачник - Регистрация</title>' +
      '<link rel="stylesheet" href="/css/style.css">' +
      '<link rel="stylesheet" href="/css/register.css">' +
    '</head>' +
    '<body>' +
      '<div class="container">' +
        '<form class="register" method="POST" action="/Project1.dll/register">' +
          '<h1>Регистрация</h1>' +
          errorCode +
          '<input type="text" class="register-input" name="login" value="' + HtmlEncode(formLogin) + '" maxlength="15" placeholder="Придумайте логин" required>' +
          '<input type="password" class="register-input" name="password" maxlength="128" placeholder="Придумайте пароль" required>' +
          '<input type="password" class="register-input" name="passwordRepeat" maxlength="128" placeholder="Повторите пароль" required>' +
          '<input type="submit" class="register-submit" value="Зарегистрироваться">' +
          '<a href="/Project1.dll/login" class="register-link">Уже есть аккаунт? Войти</a>' +
        '</form>' +
      '</div>' +
    '</body>' +
  '</html>';
end;


end.

object WebModule1: TWebModule1
  Actions = <
    item
      Default = True
      Name = 'DefaultHandler'
      PathInfo = '/'
      OnAction = WebModule1DefaultHandlerAction
    end
    item
      Name = 'LoginAction'
      PathInfo = '/login'
      OnAction = WebModule1LoginActionAction
    end
    item
      Name = 'RegisterAction'
      PathInfo = '/register'
      OnAction = WebModule1RegisterActionAction
    end
    item
      Name = 'CreateAction'
      PathInfo = '/create'
      OnAction = WebModule1CreateActionAction
    end
    item
      Name = 'ExitAction'
      PathInfo = '/exit'
      OnAction = WebModule1ExitActionAction
    end
    item
      Name = 'DeleteAction'
      PathInfo = '/delete'
      OnAction = WebModule1DeleteActionAction
    end
    item
      Name = 'EditAction'
      PathInfo = '/edit'
      OnAction = WebModule1EditActionAction
    end>
  Height = 230
  Width = 415
  object ADOConnection1: TADOConnection
    Connected = True
    ConnectionString = 
      'Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security In' +
      'fo=False;Initial Catalog=TaskManager;Data Source=localhost\SQLEX' +
      'PRESS;'
    LoginPrompt = False
    Provider = 'SQLOLEDB.1'
    Left = 64
    Top = 96
  end
  object ADOQuery1: TADOQuery
    Connection = ADOConnection1
    Parameters = <>
    Left = 160
    Top = 96
  end
end

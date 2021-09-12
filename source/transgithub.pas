unit transgithub;

{$mode ObjFPC}{$H+}

{ A class thats perhaps no more than a demonstrator on how to work with Github.
  It looks difficult to use the tomboy-ng trans model because we compare notes
  differently, have to use the sha rather than lastchangedate.

  State of Play, August 2021
  Can create a remote repo, testing users Token and confirming repo available.
  We have tools to upload and down notes doing md conversions on the fly.
  Can read the "LCD" from a github file.
  Tested the index idea.
  No evidence here of the model of allowing user to select to upload and sync with
  either viewable/editable notes OR encrypted (Blowfish ?) ones. Just thought
  experiemnt at this stage. But seeems feasable.

  DoRemoteManifest now requires that we pass the RemoteMetaData to it and it needs
  access to NoteLister so it can get a list of Notebooks, thats going to be interesting.

  https://github.com/settings/tokens to generate a Person Access Token

  -------------- P E R S O N A L    A C C E S S   T O K E N S ------------------

  From a logged in to github page, click my pretty picture, top right. Then 'Settings'.
  on left sidebar, click 'Developer",  "Personal Access Token".
}

// ToDo : if we record the sha and LCD string in remote manifest, then if that sha
// matches the sha from the actual file, then we can use that LCD St to compare
// notes in the event of a clash (ie a (re)join with notes at both ends). This
// will not help for notes edited on github website but will cover note changed.

// ToDo : must deal better with Templates.
// Right now, a template, once uploaded to git, is seen as a ordinary note and downloads as such.
// Don't think we can leave a Template out, someone may have deliberate info in there
// eg my .1 manpage template.  So, detect a note is a template on the way up, mark
// it as such on the way back ?

{$define DEBUG}

interface

uses
    Classes, SysUtils, fpjson, jsonparser, syncutils {$ifndef TESTRIG}, trans{$endif};

type TFileFormat = (
                ffNone,               // Format not, at this stage specified
                ffEncrypt,            // File is encrypted
                ffMarkDown);          // File is in MarkDown, CommonMark

type
      PGitNote=^TGitNote;
      TGitNote = record
            FName : string;     // eg README.txt, Meta/serverid, Notes/<guid>.md
            Sha   : string;     // The SHA, we always have this.
            Title : string;     // Last known note title.
            Date  : string;     // The Last Change Date of the note. Always can get that.
            CDate : string;     // The create Date, we may not know it if its a new note.
            Format : TFileFormat;       // How the file is saved at github, md only at present
            Notebooks : string; // maybe empty, else ["notebook1", "notebook2"] etc. Only needed for SyDownLoad
      end;

type
    { TGitNoteList }
TGitNoteList = class(TFPList)
    private
        procedure DumpList(wherefrom : string);
        function Get(Index: integer): PGitNote;

     public
         constructor Create();
         destructor Destroy; override;
                            // Adds an item, found in the JSON, to list, does NOT check for duplicates.
                            // Only gets Name (that is, FileName maybe with dir prepended) and sha.
         function AddJItem(jItm: TJSONData; Prefix: string): boolean;
         function Add(AGitNote : PGitNote) : integer;
                            // Adds or updates record, FName being key.
         procedure Add(const FName, Sha: string);
                            // Adds data to list, uses only non-empty items. Entry must exist in list, so
                            // FName is required and sensibly, at least one more item.
         procedure InsertData(const FName, Title, DateSt, CDate, Notebooks: string; const Format: TFileFormat);
         function FNameExists(FName: string; out Sha: string): boolean;
         function Find(const ID: string): PGitNote;
         property Items[Index: integer]: PGitNote read Get; default;
     end;




type

{ TGitHub }

 { TGitHubSync }

  {$ifdef TESTRIG}
 TGitHubSync = class
 {$else}
 TGithubSync = class(TTomboyTrans)
 {$endif}
  private
                            { Private : Initialised in TestConnection which calls ScanRemoteRepo
                            to put an ID and sha entry in, then ReadRemoteManifest to fill in
                            cdate, format, title and notebooks.
                            AssignAction will add locally know notes and and actions.}
        RemoteNotes : TGitNoteList;
        HeaderOut : string;             // Very ugly global to get optional value back from Downloader
                                        // ToDo : do better than this Davo

        procedure ErrorLogger(ESt : string);

                            // A general purpose downloader, results in JSON, if downloading a file we need
                            // to pass the Strings through ExtractContent() to do JSON and base64 stuff.
                            // This method may set ErrorMessage, it might need resetting afterwards.
                            // The two optional parameter must be used together and extract one header value.
        function Downloader(URL: string; out SomeString: String; const Header: string =''): boolean;

        procedure DumpJSON(const St: string; WhereFrom: string = '');
        procedure DumpMultiJSON(const St: string);
                            // Finds a Z datest in the Commit Response, tolerates, to some extent
                            // unexpected JSON but must not get an array, even a one element one.
        function ExtractLCD(const St: string; out DateSt: string): boolean;
                            // Reads the (json) remote manifest, adding cdate, format and Notebooks to RemoteNotes.
                            // Assumes RemoteNotes is created, comms tested. Ret false if cannot find remote
                            //  manifest.  All a best effort approach, a github created note will not be listed.
        function ReadRemoteManifest(): boolean;
                            // Generic Putting / Posting Method. Put = False means Post. If an FName is provided
                            // then its a file upload, record the sha in RemoteNotes.
        function SendData(const URL, BodyJSt: String; Put: boolean; FName: string = ''): boolean;
                            // Returns URL like https://api.github.com/repos/davidbannon/tb_test/contents
                            // Requires UserName, RemoteRepoName and does not have trailing /
        function ContentsURL(API: boolean): string;
        function ExtractJSONField(const data, Key: string; ItemNo: integer = - 1 ): string;
        function GetServerId() : string;

                            // Creates a file at remote using contents of List. RemoteFName may be
                            // something like Meta/serverid for example. Checks RemoteNotes to see if
                            // file already exists and does update node if it does. No dir is defaulted to.
        function SendFile(RemoteFName: string; STL: TstringList): boolean;

                            // Makes a new remote repo if it does not exist, if called when repo
                            // does exist, will check that a serverID is present and just return false
                            // If the ServerID is NOT present, will make one and return true
        function MakeRemoteRepo() : boolean;

        function SendNote(ID: string): boolean;
                            // Scans the top level of the repo and then Notes and Meta recording in me and
                            // RemoteNotes the filename and sha for every remote file it finds.
        function ScanRemoteRepo() : boolean;

                            // Returns true if it has written temp file named ID.note-temp in Note format in the
                            // NotesDir. Assumes it can write in NotesDir. If FFName provided, saves there instead.
                            // FFName, if provided, must include path and extension and must be writable.
        function DownloadANote(const NoteID: string; FFName: string = ''): boolean;





  public
        //UserName : string;
        //RemoteRepoName : string;                // eg tb_test, tb_notes

        TokenExpires : string;                  // Will have token expire date after TestTransport()
        {$ifdef TESTRIG}                        // This is defined in Trans, remove it or hid it !
        RemoteServerRev : integer;
        ServerID : string;
        ErrorString : string;
        Password    : string;
        {$endif}

        (* ------------- Defined in parent class ----------------
        Password : string;          // A password for those Transports that need one.
        DebugMode : boolean;
        ANewRepo : Boolean;         // Indicates its a new repo, don't look for remote manifest.
        ErrorString : string;       // Set to '' is no errors.
        NotesDir, ConfigDir : string;     // Local notes directory
        RemoteAddress : string;     // A url to network server or 'remote' file directory for FileSync
        ServerID : string;          { The current server ID. Is set with a successful TestTransport call. }
        RemoteServerRev : integer;  { The current Server Rev, before we upload. Is set with a successful  TestTransport call. }
        *)

        constructor Create();
        destructor Destroy; override;

        // --------------- Methods required to be here by Trans ----------------

                                { GitHub - tries to contact Github, testing UserName, Token and tries to scan the
                                remote files putting ID and SHA into RemoteNotes.  If WriteNewID is true, tries
                                to create repo first. Does no fill in LCD, will need to be done, note by note later.
                                Might return SyncNetworkError, SyncNoRemoteMan, SyncReady, SyncCredentialError  }
        function TestTransport(const WriteNewServerID: boolean = False): TSyncAvailable;   {$ifndef TESTRIG} override;{$endif}

                                // Checks Temp dir, should empty it, ret TSyncReady or SyncBadError
        function SetTransport() : TSyncAvailable;  {$ifndef TESTRIG} override;{$endif}


                                 { Github : This is just a stub here, does nothing. We populate RemoteNotes in AssignAction()}
        function GetRemoteNotes(const NoteMeta : TNoteInfoList; const GetLCD : boolean) : boolean;  {$ifndef TESTRIG} override;{$endif}

        function DownloadNotes(const DownLoads: TNoteInfoList): boolean;   {$ifndef TESTRIG} override;{$endif}

        function DeleteNote(const ID : string; const ExistRev : integer) : boolean;  {$ifndef TESTRIG} override;{$endif}

                                 {Github : we pass SendNote an ID and remote filename, it looks after updating
                                 RemoteNotes data structure,  }
        function UploadNotes(const Uploads: TStringList): boolean;  {$ifndef TESTRIG} override;{$endif}


                                {GitHub : Has to make Meta/mainfest.json and README.md. ignores RevNo
                                and the passed manifest, We must have the RemoteMetaData which tells us
                                which notes apply, CDate, LCD etc. Notebooks comes from NoteLister. Must
                                be called after syncing done so it can copy SHA data to RemoteMetaData.
                                Make just a flat index but in future, some sort of notebook organisation.
                                Generate suitable content, upload it, README.md to Github. }
        function DoRemoteManifest(const RemoteManifest : string; MetaData : TNoteInfoList = nil) : boolean; {$ifndef TESTRIG} override;{$endif}

                                { Github - Downloads indicated note to temp dir, returns FFname is OK
                                The downloaded file should be reusable in this session if its later needed }
        function DownLoadNote(const ID : string; const RevNo : Integer) : string; {$ifndef TESTRIG} override;{$endif}        // ToDo : maybe need implement this ? For clash processing.

                                { Public - but not defined in Trans.
                                Gets passed both Remote and Local MetaData lists, makes changes to only Remote.
                                Relies on RemoteNotes, LocalMeta and NoteLister to fill in all details  (inc
                                Action) of all notes that are currently on remote server. Then  scans  over
                                NoteLister adding any notes it finds that are not already in RemoteMetaData and
                                marks them as SyUploads. Also adds the new NoteLister notes to RemoteNotes if
                                NOT a TestRun.}

        function AssignActions(RMData, LMData: TNoteInfoList; TestRun: boolean): boolean;

end;


// =============================================================================

implementation

uses
    {$if (FPC_FULLVERSION=30200)}  opensslsockets, {$endif}  // only available in FPC320 and later
    {$ifdef LCL}  lazlogger, {$endif}                        // trying to not be dependent on LCL
    fphttpclient, httpprotocol, base64,
    LazUTF8, LazFileUtils, fpopenssl, {ssockets,} DateUtils, fileutil,
    CommonMark, import_notes,
    Note_Lister, TB_Utils;

const
  GitBaseURL='https://github.com/';
  BaseURL='https://api.github.com/';

  RNotesDir='Notes/';
  RMetaDir='Meta/';
  RemoteRepoName='tb_test';
  {$ifdef TESTRIG}
  NotesDir='/home/dbannon/Pascal/GithubAPI/notes/';
  UserName='davidbannon';
  DebugMode=true;
  {$endif}
  TempDir='Temp/';
  // see also UserName (eg davidbannon) and RemoteRepoName (eg tb_test)

// ================================ TGitNoteList ===============================

function TGitNoteList.Get(Index: integer): PGitNote;
begin
    Result := PGitNote(inherited get(Index));
end;

procedure TGitNoteList.DumpList(wherefrom: string);
var
    i : integer = 0;
    {Notebooks,} Format : string;
begin
    if Wherefrom <> '' then
        SayDebugSafe('-------- TransGithub RemoteNotes ' + Wherefrom + '----------');
    while i < count do begin
        case Items[i]^.Format of
            ffNone : Format := 'not set';
            ffEncrypt : Format := 'Encrypt';
            ffMarkDown : format := 'Markdown';
        end;
        SayDebugSafe('List - ID=[' + Items[i]^.FName + '] Sha=' + Items[i]^.Sha + ' Date=' + Items[i]^.Date);
        SaydebugSafe('       CDate=' + Items[i]^.CDate + '  Format=' + Format + ' Title=' + Items[i]^.Title + ' Notebooks=' + Items[i]^.Notebooks);
        inc(i);
    end;
end;

constructor TGitNoteList.Create();
begin
     inherited Create;
end;

destructor TGitNoteList.Destroy;
var
    i : integer;
begin
    for I := 0 to Count-1 do begin
    	dispose(Items[I]);
	end;
    inherited Destroy;
end;


function TGitNoteList.AddJItem(jItm: TJSONData; Prefix : string): boolean;
var
    jObj : TJSONObject;
    jBool : TJSONBoolean;
    PNote : PGitNote;
    jString : TJSONString;
begin
    Result := False;
    jObj := TJSONObject(jItm);
    if not ((JObj.Find('error', jBool) and (jBool.AsBoolean = true))) then begin
            new(PNote);
            PNote^.FName := '';
            PNote^.Title := '';
            PNote^.Date := '';
            PNote^.CDate := '';
            PNote^.Format := ffNone;
            if jObj.Find('name', jString) then begin
                    pNote^.FName := Prefix + JString.AsString;
            end else begin
                    dispose(PNote);
                    exit(SayDebugSafe('GitHubList.AddJItem : Failed to find note name'));
            end;
            if jObj.Find('sha', jString) then
                PNote^.sha := JString.AsString
            else begin
                    dispose(PNote);
                    exit(SayDebugSafe('GitHubList.AddJItem : Failed to find note sha'));
            end;
            add(PNote);
            Result := True;
    end else Result := False;
end;

function TGitNoteList.Add(AGitNote: PGitNote): integer;
begin
    result := inherited Add(AGitNote);
end;

// Adds or updates record, FName being key.
procedure TGitNoteList.Add(const FName, Sha: string);
var
    PNote : PGitNote;
    i : integer = 0;
begin
    while i < count do begin
        if Items[i]^.FName = FName then begin
            Items[i]^.Sha := Sha;
            exit;
        end;
        inc(i);
    end;                    // OK, must be a new entry
    new(PNote);
    PNote^.FName := FName;
    PNote^.Sha := Sha;
    PNote^.Title := '';
    PNote^.Date := '';
    PNote^.CDate := '';
    PNote^.Format := ffNone;
    Add(PNote);
end;


procedure TGitNoteList.InsertData(const FName, Title, DateSt, CDate, Notebooks : string; const Format : TFileFormat);
var
  i : integer = 0;
begin
    while i < count do begin
        if Items[i]^.FName = FName then begin
            if Title <> '' then
                Items[i]^.Title := Title;
            if DateSt <> '' then
                Items[i]^.Date := DateSt;
            if CDate <> '' then
                Items[i]^.CDate := CDate;
            if Format <> ffNone then
                Items[i]^.Format := Format;
            if Notebooks <> '' then
                Items[i]^.Notebooks := Notebooks;
            exit;
        end;
        inc(i);
    end;
    SayDebugSafe('GitHub.InsertData : Failed to find ' + FName + ' to insert date');
end;

// Returns true and sets sha if note is in List. Ignores trailing / in FName.
// If the Note exists in the list but its sha is not set, ret True but sha is empty
function TGitNoteList.FNameExists(FName: string; out Sha: string): boolean;
var
  i : integer = 0;
begin
    Sha := '';
    if FName[length(FName)] = '/' then
        FName := FName.remove(length(FName)-1);   // its part of a URL so don't reverse for windows !
    while i < count do begin
        if Items[i]^.FName = FName then begin
            Sha := Items[i]^.Sha;
            exit(True);
        end;
        inc(i);
    end;
    debugln('TGitNoteList.FNameExists did not find ID=[' + FName +']');
    result := False;
end;

function TGitNoteList.Find(const ID : string): PGitNote;
var
    i : integer = 0;
begin
    while i < count do begin
        if Items[i]^.FName = RNotesDir + ID + '.md' then        // first, assume its a note
            exit(Items[i]);
        if Items[i]^.FName = ID then                            // but also try as if its a FFName
            exit(Items[i]);
        inc(i);
    end;
    Result := Nil;
end;



// =========================== T G i t   H u b  ================================

// ---------------- P U B L I C   M E T H O D S  ie from Trans -----------------



function TGithubSync.TestTransport(const WriteNewServerID: boolean): TSyncAvailable;
{  If we initially fail to find offered user account, try defunkt so we can tell if
   its a network error or username one.  }
var
   St : string;
begin
    ErrorString := '';
    debugln('TGithubSync.TestTransport - called');
    if ANewRepo and WriteNewServerID then           // Will fail ? if repo already exists.
        MakeRemoteRepo();
    if RemoteNotes <> Nil then RemoteNotes.Free;
    RemoteNotes := TGitNoteList.Create();
    if ProgressProcedure <> nil then ProgressProcedure('Testing Credentials');
    debugln('TGithubSync.TestTransport - about to get auth-token-expire');
    debugln('URL=' + BaseURL + 'users/' + UserName);
    if DownLoader(BaseURL + 'users/' + UserName, ST,
                        'github-authentication-token-expiration') then begin
        // So, does nominated user account exist ?
        if ExtractJSONField(ST, 'login') = UserName then begin     // "A" valid username
            TokenExpires := HeaderOut;
            SayDebugSafe('Confirmed login OK');
            if TokenExpires = '' then begin
                ErrorString := 'Username exists but Token Failure';
                exit(SyncCredentialError);              // Password failure
            end;
            // If to here, we have a valid username and a valid Password but don't know if they work together
            if ProgressProcedure <> nil then progressProcedure('Looking at ServerID');
            ServerID := GetServerId();
            debugln('TGithubSync.TestTransport : serverID is ' + ServerID);
            if ServerID = '' then begin
                ErrorString := 'Failed to get a ServerID';
                exit(SyncNoRemoteRepo)
            end
            else begin
                if ProgressProcedure <> nil then progressProcedure('Scaning remote files');
                if not ScanRemoteRepo() then exit(SyncBadRemote);
                if (not ReadRemoteManifest()) then begin
                        debugln('TGithubSync.TestTransport ReadRemoteManifest returned false');
                        if (not ANewRepo) then
                            exit(SyncNoRemoteMan);
                end;


                Result := SyncReady;
                if ProgressProcedure <> nil then progressProcedure('TestTransport Happy')
            end;
        end else ErrorLogger('Spoke to Github but did not confirm login');
    end else begin
        ErrorLogger('Download failed URL=' + BaseURL + 'users/' + UserName);
        if DownLoader(BaseURL + 'users/defunkt', ST) then begin
            ErrorString := 'Username is not valid : ' + UserName;
            exit(SyncCredentialError);
        end
        else exit(SyncNetworkError);
    end;
end;

function TGithubSync.SetTransport(): TSyncAvailable;
begin
    if DebugMode then saydebugSafe('TGithubSync.SetTransport - called');
    if not directoryexists(NotesDir + TempDir) then
        ForceDirectory(NotesDir + TempDir);
    if directoryexists(NotesDir + TempDir)
            and DirectoryIsWritable(NotesDir + TempDir) then
        result := SyncReady
    else begin
        SayDebugSafe('Cannot use dir : ' + NotesDir + TempDir);
        exit(SyncBadError);
    end;                                        // ToDo : we should empty temp dir now, and reuse any downloaded notes if possible.
end;

function TGithubSync.DownloadNotes(const DownLoads: TNoteInfoList): boolean; // overload;
var
    I : integer;
    FullFileName : string;
begin
    if not DirectoryExists(NotesDir + 'Backup') then
        if not ForceDirectory(NotesDir + 'Backup') then begin
            ErrorString := 'Failed to create Backup directory.';
            exit(False);
        end;
    for I := 0 to DownLoads.Count-1 do begin
        if DownLoads.Items[I]^.Action = SyDownLoad then begin
            if FileExists(NotesDir + Downloads.Items[I]^.ID + '.note') then
                // First make a Backup copy
                if not CopyFile(NotesDir + Downloads.Items[I]^.ID + '.note',
                        NotesDir + 'Backup' + PathDelim + Downloads.Items[I]^.ID + '.note') then begin
                    ErrorString := 'GitHub.DownloadNotes Failed to copy file to Backup ' + NotesDir + Downloads.Items[I]^.ID + '.note';
                    exit(False);
                end;
            FullFileName := NotesDir + TempDir + Downloads.Items[I]^.ID + '.note';
            if not FileExists(FullFileName) then
                Result := DownloadANote(Downloads.Items[I]^.ID, FullFileName)   // OK, now download the file,
            else Result := True;                                                // we must have downloaded it to resolve clash
            if Result and fileexists(FullFileName)  then begin                  // to be sure, to be sure
                    deletefile(NotesDir + Downloads.Items[I]^.ID + '.note');
                    renamefile(FullFileName, NotesDir + Downloads.Items[I]^.ID + '.note');
            end else begin
                ErrorString := 'GitHub.DownloadNotes Failed to download ' + FullFileName;
                exit(SayDebugSafe('TGithubSync.DownloadNotes - ERROR, failed to down to ' + FullFileName));
            end;
        end;
    end;
end;

function TGithubSync.DeleteNote(const ID: string; const ExistRev: integer
    ): boolean;
//   https://docs.github.com/en/rest/reference/repos#delete-a-file
var
    Response : TStringList;
    Client: TFPHttpClient;
    BodyStr, Sha : string;
    RFName : string;
begin
    Result := false;
    RFName := RNotesDir + ID + '.md';
    if not (RemoteNotes.FNameExists(RFName, Sha) and (Sha <> '')) then begin   // Try for an ID first.
        RFName := ID;
        if not (RemoteNotes.FNameExists(RFName, Sha) and (Sha <> '')) then begin   // Failing an ID, we will try "as is".
            ErrorLogger('TGitHubSync.DeleteNote ERROR did not find sha for ' + ID);
            exit(false);
        end;
    end;
    BodyStr :=  '{ "message": "update upload", "sha" : "' + Sha + '" }';
    Client := TFPHttpClient.create(nil);
    Response := TStringList.create;
    try
        Client.AddHeader('User-Agent','Mozilla/5.0 (compatible; fpweb)');
        Client.AddHeader('Content-Type','application/json; charset=UTF-8');
        Client.AddHeader('Accept', 'application/json');
        Client.AllowRedirect := true;
        Client.UserName:=UserName;
        Client.Password:=Password;
        client.RequestBody := TRawByteStringStream.Create(BodyStr);
        Client.Delete(ContentsURL(True) + '/' + RFName,  Response);
        Result := (Client.ResponseStatusCode = 200);
        if not Result then begin
                ErrorLogger('TGitHubSync.DeleteNote : Delete ret ' + inttostr(Client.ResponseStatusCode));
                saydebugsafe('URL=' + ContentsURL(true) + '/' + RFName);
                saydebugsafe(' ------------- Delete Response  ------------');
                saydebugsafe(Response.text);
                saydebugsafe(' ------------- Delete Response End ------------');
        end;
    finally
        Response.free;
        Client.RequestBody.Free;
        Client.Free;
    end;
end;


function TGithubSync.GetRemoteNotes(const NoteMeta: TNoteInfoList;
    const GetLCD: boolean): boolean;
begin
    if (RemoteNotes = Nil) or (NoteMeta = Nil) then exit(SayDebugSafe('TGitHubSync.GetRemoteNotes ERROR getRemoteNotes called with nil list'));
    result := True;
end;

function TGithubSync.UploadNotes(const Uploads: TStringList): boolean;
var
    St : string;
begin
    RemoteNotes.DumpList('TGitHubSync.UploadNotes : About to send a bunch of notes');
    for St in Uploads do
        if not SendNote(St) then exit(false);
    result := true;
end;

function TGithubSync.DoRemoteManifest(const RemoteManifest: string; MetaData: TNoteInfoList): boolean;
var
    P : PNoteInfo;      // an item from RemoteMetaData
    PGit : PGitNote;    // an item from local data structure, RemoteNotes
    Readme, manifest : TStringList;
    St, Notebooks : string;
begin
    // ToDo : ensure this does not write new manifest / README if no changes were made.
    //Note : we do not use the supplied XML RemoteManifest, we build our own json one.
    Result := false;
    Readme := TstringList.Create;
    Manifest := TstringList.Create;
    Readme.Append('## My tomboy-ng Notes');
    // * [Note Title](https://github.com/davidbannon/tb_demo/blob/main/Notes/287CAB9C-A75F-4FAF-A3A4-058DDB1BA982.md)
    Manifest.Append('{' + #10'  "notes" : {');
    (*   "1DB87478-C301-48B5-950E-5F17A438C347" : {
               "title" : "some note title",
               "create-date" :   "2017-10-16T11:04:54.1237020+11:00",
               "format" : "md",
               "notebooks" :      -- OR --    "notebooks" : ["notebook1", "notebook2"]   etc
          },   *)
    try
        if MetaData = nil then exit(SayDebugSafe('TGithubSync.DoRemoteManifest ERROR, passed a nil metadata list'));
        for P in MetaData do begin
            if P^.Action in [ SyNothing, SyUploadNew, SyUploadEdit, SyDownload, SyClash ] then begin  // SyClash ? I don't think so .....
                // These notes will be the ones that end up on GitHub after we finish.
                PGit := RemoteNotes.Find(P^.ID);
                if PGit = nil then
                    exit(SayDebugSafe('TGitHubSync.DoRemoteManifest - ERROR, failed to find ID from RemoteMetaData in RemoteNotes'));
                Readme.Append('* [' + P^.Title + '](' + ContentsURL(False) + PGit^.FName + ')');
                if P^.Action = SyDownload then
                    NoteBooks := PGit^.Notebooks
                else
                    NoteBooks := TheNoteLister.NotebookJArray(P^.ID + '.note');
                Manifest.Append('    "' + P^.ID + '" : {'#10
                        + '      "title" : "' + P^.Title + '",'#10                                           // ToDo : confirm
                        + '      "cdate" : "' + P^.CreateDate + '",'#10
                        + '      "format" : "md",'#10
                        + '      "notebooks" : '+ NoteBooks + #10 + '    },');   // should be empty string or eg ["one", "two"]
            end;
        end;
        // Remove that annoying trailing comma from last block
        if manifest.count > 0 then begin
            St := manifest[manifest.count-1];
            if St[St.Length] = ',' then begin
                delete(St, St.Length, 1);
                manifest.Delete(manifest.count-1);
                manifest.append(St);
            end;
        end;
        Readme.append('');
        Readme.append('***Please remember that to ensure a reliable sync, you must not change files in the Meta directory.***');
        Manifest.Append('  }'#10 + '}'#10);
        for PGit in RemoteNotes do                      // Put all the SHAs we know about into RemoteMetaData (for local manifest);
            if PGit^.Sha <> '' then begin
                P := MetaData.FindID(extractFileNameOnly(PGit^.FName));
                if P <> nil then
                    P^.Sha := PGit^.Sha;
            end;
        if not SendFile(RMetaDir + 'manifest.json', Manifest) then SayDebugSafe('TGitHubSync.DoRemoteManifest ERROR, failed to write remote manifest');
        if not SendFile('README.md', Readme) then SayDebugSafe('TGitHubSync.DoRemoteManifest ERROR, failed to write remote README');

(*        Saydebugsafe('------------- README.md ---------------');
        Saydebugsafe(Readme.text);
        Saydebugsafe('------------- Manifest.json -----------');
        saydebugsafe(Manifest.text);      *)
        result := true;
    finally
        Manifest.Free;
        Readme.Free;
    end;
end;

function TGithubSync.DownLoadNote(const ID: string; const RevNo: Integer): string;
begin
   if DownloadANote(ID, NotesDir + TempDir + ID + '.note') then
       Result := NotesDir + TempDir + ID + '.note'
   else Result := '';
end;

// ToDo : work through this better, are we risking race conditions here ?

const Seconds5 = 0.00005;          // Very roughly, 5 seconds

function TGithubSync.AssignActions(RMData, LMData: TNoteInfoList; TestRun : boolean): boolean;
var
    PGit : PGitNote;
    RemRec, LocRec : PNoteInfo;
    I : integer;
    NLister : PNote;
    pNBook: PNoteBook;
    LCDate, CDate : string;
begin
    // RMData should be empty, LMData will be empty if its a Join.
    Result := True;
    {$ifdef DEBUG}
    debugln('==================================================================');
    debugln('                  A S S I G N    A C T I O N S ');
    debugln('==================================================================');
    RMData.DumpList('TGithubSync.AssignActions.start RemoteMD');
    LMData.DumpList('TGithubSync.AssignActions.start LocalMD');
    RemoteNotes.DumpList('TGithubSync.AssignActions.start RemoteNotes');
    {$endif}
    for PGit in RemoteNotes do begin                                            // First, put an entry in RemoteMetaData for every remote note.
        if copy(PGit^.FName, 1, length(RNotesDir)) <> RNotesDir then continue;
        // Every note we see in this loop exists remotely. But may not exist locally.
        new(RemRec);
        RemRec^.ID := extractFileNameOnly(PGit^.FName);
        LocRec := LMData.FindID(RemRec^.ID);                                    // Nil is OK, just means the note is not in LocalMetaData
        RemRec^.CreateDate := PGit^.CDate;                                      // We may not have this, unlikely but possible
        RemRec^.LastChange := PGit^.Date;
        RemRec^.Deleted := false;
        RemRec^.Rev := 0;
        RemRec^.SID := 0;
        RemRec^.Title := TheNoteLister.GetTitle(RemRec^.ID);                    // We 'prefer' the local title, remote one may be different
        if RemRec^.Title = '' then
            RemRec^.Title := TheNoteLister.GetNotebookName(RemRec^.ID);         // Maybe its a template ?
        RemRec^.Action := SyUnset;
        if RemRec^.Title = '' then begin                                        // Not in Notelister, must be new or locally deleted
            debugln('TGithubSync.AssignActions setting ' + RemRec^.ID + ' to Download #1');
            RemRec^.Action := SyDownLoad;                                       // May get changed to SyDeleteRemote
            RemRec^.Title := PGit^.Title;                                       // One we prepared earlier, from remote manifest
            {$ifdef DEBUG}
            SayDebugSafe('TGithubSync.AssignActions RemRec^.Title = ' + RemRec^.Title);
            SayDebugSafe('TGithubSync.AssignActions PGit^.Title = ' + PGit^.Title);
            {$endif}
        end
        else begin                                                              // OK, it exists at both ends, now we need to look closely.

            debugln('TGithubSync.AssignActions - Possibe clash LMData.LastSyncDate UTC= ' +  FormatDateTime('YYYY MM DD : hh:mm', LMData.LastSyncDate ));
            // if LastSyncDate is '', a Join. An ID that exists at both ends is a clash.
            // ToDo : Maybe later on we can do an intelligent 'merge' but not now.
            if  LMData.LastSyncDate < 1.0 then                                  // Not valid
                RemRec^.Action := SyClash
            else begin
                if  (TB_GetGMTFromStr(TheNoteLister.GetLastChangeDate(RemRec^.ID)) - Seconds5)
                        > LMData.LastSyncDate then RemRec^.Action := SyUploadEdit;  // changed since last sync ? Upload it !
                if  LocRec = Nil then begin                                         // ?? If it exists at both ends we must have uploaded it ??
                    debugln('TGitHubSync.AssignActions ERROR, ID not found in LocalMetaData');
                    dispose(RemRec);
                    exit(False);
                end else if PGit^.Sha <> LocRec^.Sha then begin                 // Ah, its been changed remotely
                    if RemRec^.Action = SyUnset then begin
                        debugln('TGithubSync.AssignActions setting ' + RemRec^.ID + ' to Download #2');
                        debugln('PGit^.Sha=' + PGit^.Sha + ' and  LocRec^.Sha=' + LocRec^.Sha);
                        RemRec^.Action := SyDownLoad                            // Good, only remotely
                    end
                    else begin
                        RemRec^.Action := SyClash;                             // There is a problem to solve elsewhere.
                        debugln('TGitHubSync.AssignActions - assigning clash');
                        debugln('sha from remote=' + PGit^.Sha + ' and local=' + LocRec^.Sha);
                    end;
                end;
            end;
             debugln('TGithubSync.AssignActions - Possibe clash becomes ' + RMData.ActionName(RemRec^.Action));
        end;
        if RemRec^.Action = SyUnset then
             RemRec^.Action := SyNothing;
        RMData.Add(RemRec);
    end;
    for i := 0 to TheNoteLister.GetNoteCount() -1 do begin                      // OK, now whats in NoteLister but not RemoteNotes ?
        NLister := TheNoteLister.GetNote(i);
        if NLister = nil then exit(SayDebugSafe('TGitHubSync.AssignActions ERROR - not finding NoteLister Content'));
        // Look for items in NoteLister that do not currently exist in RemoteMetaData. If we find one,
        // we will add it to both RemoteMetaData and RemoteNodes (because its needed to store sha on upload)
        if RMData.FindID(extractfilenameonly(NLister^.ID)) = nil then begin
            if not TestRun then begin
                new(PGit);
                PGit^.FName := RNotesDir + extractfilenameonly(NLister^.ID) + '.md';                     // ToDo : Careful, assumes markdown
                PGit^.Sha := '';
                PGit^.Notebooks := '';
                PGit^.CDate := NLister^.CreateDate;
                PGit^.Date := NLister^.LastChange;
                PGit^.Format := ffMarkDown;
                RemoteNotes.Add(PGit);
            end;
            new(RemRec);
            RemRec^.ID := extractfilenameonly(NLister^.ID);
            RemRec^.LastChange := NLister^.LastChange;
            RemRec^.CreateDate := NLister^.CreateDate;
            RemRec^.Sha := '';
            RemRec^.Title := NLister^.Title;
            RemRec^.Action := SyUploadNew;
            RemRec^.Deleted := False;
            RemRec^.Rev := 0;
            RemRec^.SID := 0;
            RMData.Add(RemRec);
        end else debugln('TGithubSync.AssignActions - skiping because its already in RemoteNotes');
    end;
    // OK, just need to check over the Notebooks now, notebooks are NOT listed in NoteLister.Notelist !
    for i := 0 to TheNoteLister.NotebookCount() -1 do begin
        pNBook := TheNoteLister.GetNoteBook(i);
        if RMData.FindID(extractfilenameonly(pNBook^.Template)) = nil then begin
            ErrorString := '';
            CDate := GetNoteLastChangeSt(NotesDir + pNBook^.Template, ErrorString, True);
            LCDate := GetNoteLastChangeSt(NotesDir + pNBook^.Template, ErrorString, False);
            if ErrorString <> '' then
                exit(SayDebugSafe('Failed to find dates in template ' + pNBook^.Template));
            if not TestRun then begin
                new(PGit);
                PGit^.FName := RNotesDir + extractfilenameonly(pNBook^.Template) + '.md';                     // ToDo : Careful, assumes markdown
                PGit^.Sha := '';
                PGit^.Notebooks := '';
                PGit^.CDate := CDate;
                PGit^.Date := LCDate;
                PGit^.Format := ffMarkDown;
                RemoteNotes.Add(PGit);
            end;
            new(RemRec);
            RemRec^.ID := extractfilenameonly(pNBook^.Template);
            RemRec^.LastChange := LCDate;
            RemRec^.CreateDate := CDate;
            RemRec^.Sha := '';
            RemRec^.Title := pNBook^.Name;
            RemRec^.Action := SyUploadNew;
            RemRec^.Deleted := False;
            RemRec^.Rev := 0;
            RemRec^.SID := 0;
            RMData.Add(RemRec);
        end else debugln('TGithubSync.AssignActions - skiping because its already in RemoteNotes');
    end;
    {$ifdef DEBUG}
    RMData.DumpList('TGithubSync.AssignActions.End RemoteMD');
    LMData.DumpList('TGithubSync.AssignActions.End LocalMD');
    RemoteNotes.DumpList('TGithubSync.AssignActions.End RemoteNotes');
    {$endif}
end;

// ====================  P R I V A T E   M E T H O D S =========================


// ---- Seems we are not alling this ----------
// Gets (just) a LastChangeDate for remote note at this stage. Only works for IDs of notes
// Asks for the Note's commit history getting just the one most recent commit.
// This is a good idea but not a great one. Notebook memberhip changes because -
// 1. User has changed it locally - gets overridden.
// 2. Its changed on a remote desktop and been synced - works, but see 1.
// user has manually edited github manifest - thats their problem !
// OK, in 1. if user has changed note membership, note will be a 'upload'
// because LCD has changed. Similarly, a new note will be uploaded. We need
// to get the notebook list of any note about to be uploaded and add it to
// RemoteNotes as it goes past.

(*
function TGitHubSync.GetNoteLCD(ID : string) : boolean;
var
   DateSt, St : string;
   URL : string;
begin                                                     // ToDo : assumes notes are all .md  ??
    // This call brings back an array, '[one-record]'
    URL := BaseURL + 'repos/' + UserName + '/' + RemoteRepoName + '/';
    Result := DownLoader(URL + 'commits?path=' + RNotesDir + ID + '.md&per_page=1&page=1', ST);
    if Result then begin
        if St[1] = '[' then begin
            delete(St, 1, 1);
        end else ErrorLogger('GitHub.GetNoteLCD - Error, failed to remove  from array');
        if St[St.Length] = ']' then begin
            delete(St, St.Length, 1);
        end else ErrorLogger('GetNoteLCD - Error, failed to remove [ from array');
        Result := ExtractLCD(ST, DateSt);
        if Result then begin
            //ErrorLogger('Github.GetNoteLCD : GetNoteDetails Date Str = ' + DateSt);
            RemoteNotes.InsertData(RNotesDir + ID + '.md', DateSt, '', ffNone);
            //RemoteNotes.DumpList('After GetNoteDetails');
        end;
     end;
end;        *)


// Gets just an ID, uses NotesDir to load that into commonmark and then passes
// the resulting string to SendFile.  Hmm, what about NoteBooks ??
function TGithubSync.SendNote(ID: string): boolean;
var
    STL : TStringList;
    CM  : TExportCommon;
begin
    STL := TStringList.Create;
    CM := TExportCommon.Create;
    try
        CM.NotesDir := NotesDir;
        CM.GetMDcontent(ID, STL);
        if STL.Count < 1 then exit(False);
        Result := SendFile(RNotesDir + ID + '.md', STL);
    finally
        CM.Free;
        STL.Free;
    end;
end;

function TGithubSync.SendFile(RemoteFName: string; STL: TstringList): boolean;      // Public only in test mode
var
    Sha : string;
    BodyStr : string;
begin
    if RemoteNotes = nil then exit(false);
    //RemoteNotes.DumpList('SendFile Before');
    if RemoteNotes.FNameExists(RemoteFName, Sha) and (Sha <> '') then begin         // Existing file mode
        BodyStr :=  '{ "message": "update upload", "sha" : "' + Sha
                    + '", "content": "' + EncodeStringBase64(STL.Text) + '" }';
        ErrorLogger('SendFile - using sha =' + sha);
        if Sha = '' then exit(False);
    end else begin                                      // New file mode
        BodyStr :=  '{ "message": "initial upload", "content": "'
                    + EncodeStringBase64(STL.Text) + '" }';
        ErrorLogger('SendFile - NOT using sha');
    end;
    Result := SendData(ContentsURL(True) + '/' + RemoteFName, BodyStr, true, RemoteFName);
end;

function TGithubSync.MakeRemoteRepo(): boolean;
var
    GUID : TGUID;
    STL: TstringList;
begin
    // https://docs.github.com/en/rest/reference/repos#create-a-repository-for-the-authenticated-user
    Result := SendData(BaseURL + 'user/repos',
        '{ "name": "' + RemoteRepoName + '", "auto_init": true, "private": true" }',
        False);
    if (not Result) and (GetServerId() <> '') then exit(false);
    CreateGUID(GUID);
    STL := TstringList.Create;
    try
        ServerID := copy(GUIDToString(GUID), 2, 36);      // it arrives here wrapped in {}
        STL.Add(ServerID);
        Result := SendFile(RMetaDir + 'serverid', STL);         // Now, RemoteNotes does not exist at this stage !!
    finally
        STL.Free;
    end;
    //RemoteServerRev := -1;
end;


function TGithubSync.ScanRemoteRepo(): boolean;
var
    jData : TJSONData;
    jItem : TJSONData;
    i : integer;
    St : string;
    Sha : string;
begin
    Result := True;
    if Downloader(ContentsURL(True), ST) then begin
        jData := GetJson(St);
        for i := 0 to JData.Count -1 do begin                           // Each count represents one remote file
            jItem := jData.Items[i];
            if not RemoteNotes.AddJItem(JItem, '') then
                Result := False;
        end;
        jData.free;
    end else Result := False;
    if RemoteNotes.FNameExists(RNotesDir, Sha) then begin
        St := '';
        if Downloader(ContentsURL(True)+'/'+RNotesDir, ST) then begin   // Github appears to be happy with Notes and Notes/   ?
            jData := GetJson(St);
            for i := 0 to JData.Count -1 do begin                       // Each count represents one remote file
                jItem := jData.Items[i];
                if not RemoteNotes.AddJItem(JItem, RNotesDir) then
                    Result := False;
            end;
            jData.free;
        end else Result := False;
    end;
    if RemoteNotes.FNameExists(RMetaDir, Sha) then begin
        St := '';
        if Downloader(ContentsURL(True)+'/'+RMetaDir, ST) then begin
            jData := GetJson(St);
            for i := 0 to JData.Count -1 do begin                       // Each count represents on remote file
                jItem := jData.Items[i];
                if not RemoteNotes.AddJItem(JItem, RMetaDir) then
                    Result := False;
            end;
            jData.free;
        end else Result := False;
        //RemoteNotes.DumpList('Scan Remote Repo');
    end;
end;

constructor TGithubSync.Create();
begin
    ProgressProcedure := nil;           // It gets passed After create.
    RemoteNotes := Nil;
end;

destructor TGithubSync.Destroy;
begin
    if RemoteNotes <> Nil then RemoteNotes.Free;
    inherited Destroy;
end;




function TGithubSync.DownloadANote(const NoteID: string; FFName : string = ''): boolean;
var
    {STL,} NoteSTL : TStringList;
    St  : string;
    Importer : TImportNotes;
    PGit : PGitNote;
begin
    Importer := Nil;
    NoteSTL := Nil;
    Result := True;
    //STL := TStringList.Create;
    try
        PGit := RemoteNotes.Find(RNotesDir + NoteID + '.md');      // ToDo : assumes markdown
        if PGit = nil then exit(SayDebugSafe('TGithubSync.DownloadANote - ERROR, cannot find ID in RemoteNotes = ' + RNotesDir + NoteID + '.md'));
        if not Downloader(ContentsURL(True) + '/' + RNotesDir + NoteID + '.md', ST) then exit(False);
        NoteSTL := TStringList.Create;
        NoteSTL.Text := DecodeStringBase64(ExtractJSONField(ST, 'content'));
        if NoteSTL.Count > 0 then begin
                Importer := TImportNotes.Create;
                Importer.NoteBook := PGit^.Notebooks;
                Importer.MDtoNote(NoteSTL, PGit^.Date, PGit^.CDate);                             // ToDo : need to pass LCD, CDate and Notebooks ????
                // writeln(NoteSTL.TEXT);
                if FFName = '' then
                    NoteSTL.SaveToFile(NotesDir + NoteID + '.note-temp')
                else NoteSTL.SaveToFile(FFname);
        end else Result := false;
    finally
        if Importer <> Nil then Importer.Free;
        if NoteSTL <> Nil then NoteSTL.Free;
        //STL.Free;
    end;
end;


function TGithubSync.ReadRemoteManifest(): boolean;
var
   St : string;
   Notebooks : string = '';
   jData, jItem, JItem2 : TJSONData;
   i, j, k: Integer;
   // object_name, field_name, field_value, object_type, object_items: String;
   jStr : TJSONString;
   jArray : TJSONArray;
   FName : string;
begin
    if RemoteNotes.Find(RMetaDir + 'manifest.json') = nil then
        exit(SayDebugSafe('Remote manifest not present, maybe a new repo ?'));
    Result := Downloader(ContentsURL(True) + '/' + RMetaDir + 'manifest.json', ST);
    if result = false then begin
        ErrorLogger('GitHub.ReadRemoteMainfest : Failed to read the remote manifest file');
        exit;
    end;
(*    debugln('---------------- TGithubSync.ReadRemoteManifest content ----------');
    debugln(St);
    debugln('---------------- ');
    debugln(ExtractJSONField(ST, 'content'));
    debugln('---------------- ');
    debugln(DecodeStringBase64(ExtractJSONField(ST, 'content')));    *)

    jData := nil;
    try
        try
            jData := GetJSON(DecodeStringBase64(ExtractJSONField(ST, 'content')));
        except on E: Exception do
            exit(Saydebugsafe('TGithubSync.ReadRemoteManifest ERROR reading remote mainfest : ' + E.Message));
        end;

        try
            for i := 0 to jData.Count - 1 do begin
                if TJSONObject(jData).Names[i] <> 'notes' then continue;
                jItem := jData.Items[i];                                            // jItem points to 'notes'
                for j := 0 to JItem.count-1 do begin
                    FName := RNotesDir + TJSONObject(jItem).Names[j] + '.md';       // ToDo : assumes its only markdown
                    JItem2 := JItem.Items[j];                                       // jItems2 points to the individual notes field
                                                                                    // do i need to check for a nil here ?
                    if TJSONObject(jItem2).Find('title', jStr) then
                        RemoteNotes.InsertData(FName, jStr.AsString, '', '', '', ffNone)
                    else ErrorLogger('ReadRemoteManifest Failed to find title for ' + FName);
                    if TJSONObject(jItem2).Find('cdate', jStr) then
                        RemoteNotes.InsertData(FName, '', '', jStr.AsString, '', ffNone)
                    else ErrorLogger('ReadRemoteManifest Failed to find cdate for ' + FName);
                    if TJSONObject(jItem2).Find('format', jStr) then begin
                        if jStr.AsString = 'md' then
                            RemoteNotes.InsertData(FName, '', '', '', '', ffMarkDown)
                        else  RemoteNotes.InsertData(FName, '', '', '', '', ffEncrypt); // ToDo : won't work if we add more formats ??
                    end else ErrorLogger('ReadRemoteManifest Failed to find Format for ' + FName);
                    Notebooks := '';
                    if TJSONObject(jItem2).Find('notebooks', jArray) then begin
                        if (jArray <> nil) then begin
                            for k := 0 to JArray.Count-1 do
                                notebooks := notebooks + '"' + jArray.Items[k].AsString + '",';
                            if notebooks <> '' then
                                delete(notebooks, notebooks.length, 1);         // remove trailing comma
                        end;
                        notebooks := '[' + notebooks + ']';                     // no notebooks means '[]'
                    end;
                    RemoteNotes.InsertData(FName, '', '', '', Notebooks, ffNone)
                end;
            end;
        except on E: Exception do exit(Saydebugsafe('TGithubSync.ReadRemoteManifest ERROR 2 reading remote mainfest : ' + E.Message));
        end;
    finally
        if jData <> nil then jData.Free;
    end;
    RemoteNotes.DumpList('After ReadRemoteManifest');
end;

function TGithubSync.GetServerId(): string;
var
   St : string;
begin
    Result := '';
    if Downloader(ContentsURL(True) + '/' + RMetaDir + 'serverid', ST) then
        Result := DecodeStringBase64(self.ExtractJSONField(ST, 'content'));
    Result := Result.Replace(#10, '');
    Result := Result.Replace(#13, '');
    debugln('TGithubSync.GetServerId = [' + Result + ']');
end;

procedure TGithubSync.ErrorLogger(ESt: string);
begin
    ErrorString := ESt;
    {$ifdef DEBUGMODE}SayDebugSafe(ESt);{$endif}
end;


function TGithubSync.Downloader(URL: string; out SomeString: String;
    const Header: string): boolean;
var
    Client: TFPHttpClient;
begin
    // Windows can be made work with this if we push out ssl dll - see DownloaderSSL local project
    //InitSSLInterface;
    // curl -i -u $GH_USER https://api.github.com/repos/davidbannon/libappindicator3/contents/README.note
    Client := TFPHttpClient.Create(nil);
    Client.UserName := UserName;
    Client.Password := Password; // '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';
    Client.AddHeader('User-Agent','Mozilla/5.0 (compatible; fpweb)');
    Client.AddHeader('Content-Type','application/json; charset=UTF-8');
    Client.AllowRedirect := true;
    SomeString := '';
    try
        try
            SomeString := Client.Get(URL);
        except
            on E: EInOutError do begin
                ErrorLogger('Github Downloader - InOutError ' + E.Message);
                ErrorString := 'Github Downloader - InOutError ';
                exit(false);
                end;
            on E: ESSL do begin
                DebugLn('Github.Downloader -SSLError ' + E.Message);
                ErrorString := 'Github.Downloader -SSLError';
                exit(false);
                end;
            on E: Exception do begin
                DebugLn('Github.Downloader Exception ' + E.Message + ' downloading ' + URL);
                ErrorString := 'GitHub.Downloader Exception';
                case Client.ResponseStatusCode of
                    401 : ErrorString := ErrorString + ' 401 Maybe your Token has expired or password is invalid ??';
                    404 : ErrorString := ErrorString + ' 404 File not found ' + URL;
                end;
                DebugLn(ErrorString);
                exit(false);
                end;
        end;
        with Client.ResponseHeaders do begin
            if Header <> '' then begin
                if IndexOfName(Header) <> -1 then
                    HeaderOut := ValueFromIndex[IndexOfName(Header)]
                else HeaderOut := '';
            end;
        end;
    finally
        Client.Free;
    end;
    result := true;
end;

function TGithubSync.SendData(const URL, BodyJSt: String; Put: boolean;
    FName: string): boolean;
var
    Client: TFPHttpClient;
    Response : TStringStream;
begin
    Result := false;
    //SayDebugSafe('Posting to ' + URL);
    Client := TFPHttpClient.Create(nil);
    Client.AddHeader('User-Agent','Mozilla/5.0 (compatible; fpweb)');
    Client.AddHeader('Content-Type','application/json; charset=UTF-8');
    Client.AddHeader('Accept', 'application/json');
    Client.AllowRedirect := true;
    Client.UserName:=UserName;
    Client.Password:=Password;
    client.RequestBody := TRawByteStringStream.Create(BodyJSt);
    Response := TStringStream.Create('');
    try
        try
            if Put then begin
                client.Put(URL, Response);
                //DumpJSON(Response.DataString, 'SendData just after PUT');
                if FName <> '' then            // if FName is provided, is uploading a file
                    RemoteNotes.Add(FName, ExtractJSONField(Response.DataString, 'sha', 0));
            end else
                client.Post(URL, Response);  // don't use FormPost, it messes with the Content-Type value
            if (Client.ResponseStatusCode = 200) or (Client.ResponseStatusCode = 201) then
                Result := True
            else begin
                //DumpJSON(Response.DataString, 'SendData not 200/201');
                ErrorLogger('GitHub.SendData : Post ret ' + inttostr(Client.ResponseStatusCode));
            end;
        except on E:Exception do
                ErrorLogger('GitHub.SendData - bad things happened : ' + E.Message);
        end;
    finally
        Client.RequestBody.Free;
        Client.Free;
        Response.Free;
    end;
end;

function TGithubSync.ContentsURL(API: boolean): string;
begin
    if API then
        Result := BaseURL + 'repos/' + UserName + '/' + RemoteRepoName + '/contents'
    else  Result := GITBaseURL + UserName + '/' + RemoteRepoName + '/blob/main/';
end;


// -------------------- J S O N   T O O L S ------------------------------------

// Returns content asociated with Key at either toplevel (no third parameter) or
// one level down under the ItemNo indexed toplevel Key. First top level key is zero.
function TGithubSync.ExtractJSONField(const data, Key: string; ItemNo: integer
    ): string;
var
    JData, JNext : TJSONData;
    JObject : TJSONObject;
    jStr : TJSONString;
begin
    result := '';
    try
        try
            JData := GetJSON(Data);                         // requires a free
            if JData.JSONType <> jtObject then
                exit('');                                   // if this is not valid JSON !
            if ItemNo > -1 then begin                       // Go the next level down
                JNext := JData.Items[ItemNo];
                if JData.JSONType <> jtObject then
                    exit('');
            end else JNext := JData;
            if jNext.Count = 0 then exit('');               // asked for a level that does not have children
            JObject := TJSONObject(jNext);                  // does not require a free
            if jObject.Find(Key, Jstr) then                 // would seg V on invalid JSON if not for above exit
                Result := jStr.AsString;
        except
            on E:Exception do Result := '';                 // not sure if this is useful ??
        end;
    finally
        JData.Free;
    end;
    if  Result='' then self.DumpJSON(Data, 'TGitHubSync.ExtractJSONField ERROR looking for ' + Key);
end;

procedure TGithubSync.DumpJSON(const St: string; WhereFrom: string);
var
    jData : TJSONData;
begin
    if Wherefrom <> '' then
        ErrorLogger('------------ Dump from ' + Wherefrom + '-------------');
    JData := GetJSON(St);
    ErrorLogger('---------- JSON ------------');
    ErrorLogger(jData.FormatJSON);
    ErrorLogger('----------------------------');
    JData.Free;
end;

// Finds a Z datest in the Commit Response, tolerates, to some extent unexpected
// JSON but must not get an array, even a one element one. This finds its date string
// two levels down, cannot use other, generic method that only does 1 level down.
function TGithubSync.ExtractLCD(const St: string; out DateSt: string): boolean;
var
    jData : TJSONData;   JObject : TJSONObject; jStr : TJSONString;
    jItem : TJSONData;
begin
    Result := false;
    //DumpJSON(St, 'In Extract LCD');
    JData := GetJSON(St);
    try
        JItem := TJSONObject(JData.Items[2]);       //  Points to middle
        If JItem.JSONType<>jtObject then exit;
        JItem := TJSONObject(JItem.Items[0]);       // Points to bottom
        If JItem.JSONType<>jtObject then exit;
        jObject := TJSONObject(JItem);   // OK, its a JObject, lets see if we can find what we want
        if jObject.Find('date', Jstr) then begin
            DateSt := JStr.AsString;
            result := True;
        end;
    finally
        JData.free;
    end;
    (*   {  "sha" : "blar",
            "node_id" : "blar",
            "commit" : {
                "author" : {
                    "name" : "blar",
                    "email" : "blar",
                    "date" : "2021-08-11T04:09:43Z"         *)
end;

procedure TGithubSync.DumpMultiJSON(const St: string);
var
    jData : TJSONData;   JObject : TJSONObject; jStr : TJSONString;
    jItem : TJSONData;
    i : integer;
begin
    JData := GetJSON(St);
    ErrorLogger('----------ALL JSON ------------');
    ErrorLogger(jData.FormatJSON);
    ErrorLogger('----------------------------');
    if JData.Count > 0 then begin
        jItem := jData.Items[0];         // The first item, "content"
        JObject := TJSONObject(JItem);
        if jObject.Find('sha', Jstr) then
            ErrorLogger('sha = [' + jStr.AsString + ']');
    end;
    exit;

    for i := 0 to JData.Count -1 do begin
        jItem := jData.Items[i];
        ErrorLogger(jItem.FormatJSON);
        ErrorLogger('----------------------------');
    end;

    JData.Free;
end;


end.


// =============================================================================
// =============================================================================
// =============================================================================


{ Notebook Syntax -
  ---------------
A note not in any notebooks -
<tags>
</tags>

A notebook template -
<tags>
   <tag>system:template</tag>
   <tag>system:notebook:MacStuff</tag>
 </tags>

A note in a notebook -
<tags>
  <tag>system:notebook:MacStuff</tag>
</tags>
}

// ========== V A R I O U S   J S O N   R E S P O N S E S ======================

(* Commit response

   {  "sha" : "blar",
        "node_id" : "blar",
        "commit" : {
                "author" : {
                        "name" : "blar",
                        "email" : "blar",
                        "date" : "2021-08-11T04:09:43Z"
    'date', 1, 3   iff we are to add another level to ExtractJSONField()
*)










(*

{ "top_1" : "one",
  "top_2" : "two",
  "top_3" : {
            "middle_1" : "three_A",
            "middle_2" : "three_B",
            "middle_3" : {
                        "bottom_1" : "important",
                        "botton_2" : "extra_important"
                        }
            }
  }




// Saves the content of a download to a file.  Only Partially implemented !
{ function TGitHub.ExtractContent(data : string; FFN : string) : boolean;
var
    JData : TJSONData;
    JObject : TJSONObject;
    // JNumb : TJSONNumber;
    jStr : TJSONString;
begin
    Result := False;
    try
        try
            JData := GetJSON(Data);                         // requires a free
            JObject := TJSONObject(jData);                  // does not require a free
            if jObject.Find('name', Jstr) then
                SayDebug('name = ' + jStr.AsString);
            if jObject.Find('sha', Jstr) then begin
                SayDebug('sha = [' + jStr.AsString + ']');
            end;

            // Result := JObject.Get('id');                 // will raise exceptions if not present, better to use Find
            if jObject.Find('content', Jstr) then begin
                SayDebug('Content = ' + DecodeStringBase64(jStr.AsString));
                Result := True;
            end else SayDebug('No Content found');                        // same with content
        except
            on E:Exception do Result := False;               // Invalid JSON or ID not present
        end;
    finally
        JData.Free;
    end;
end; }

// Returns 'content' if its found in the one level JSON string passed. Decodes base64
// Returns an empty string on failure and sets ErrorMessage
{function TGitHub.ExtractContent(data : string) : string;
var
    JData : TJSONData;
    JObject : TJSONObject;
    jStr : TJSONString;
begin
    result := '';
    try
        try
            JData := GetJSON(Data);                         // requires a free
            JObject := TJSONObject(jData);                  // does not require a free
            if jObject.Find('content', Jstr) then
                Result := DecodeStringBase64(jStr.AsString)
            else ErrorMessage := 'Response has no "content" field';
        except
            on E:Exception do begin
                        Result := '';               // Invalid JSON or content not present
                        ErrorMessage := 'Exception while decoding JSON looking for "content"';
            end;
        end;
    finally
        JData.Free;
    end;
end;  }

// Returns the first level JSON pair value with the Field key. Safely.
// Returns an empty string if it cannot find pair or of data is invalid JSON.
{function TGitHub.ExtractJSONField(const data, Field : string) : string;
var
    JData : TJSONData;
    JObject : TJSONObject;
    jStr : TJSONString;
begin
    result := '';
    try
        try
            JData := GetJSON(Data);                         // requires a free
            if JData.JSONType <> jtObject then
                exit('');                                   // This is not valid JSON !
            JObject := TJSONObject(jData);                  // does not require a free
            if jObject.Find(Field, Jstr) then               // would seg V on invalid JSON if not for above exit
                Result := jStr.AsString;
        except
            on E:Exception do Result := '';                 // not sure if this is useful ??
        end;
    finally
        JData.Free;
    end;
    if  Result='' then self.DumpJSON(Data, 'ExtractJSONField');
end;     }


 {
function TGitHub.ExtractUploadSha(const St : string) : string;
var
    jData : TJSONData;   JObject : TJSONObject; jStr : TJSONString;
    //jItem : TJSONData;
    //i : integer;
begin
    Result := '';
    JData := GetJSON(St);
    if JData.Count > 0 then begin
        //jItem := jData.Items[0];         // The first item, "content"
        //JObject := TJSONObject(JItem);
        jObject := TJSONObject(JData.Items[0]);
        if jObject.Find('sha', Jstr) then          // ToDo : this will trigger a AV if data is not as expected - how to protect ?
            Result := jStr.AsString;
    end;
    JData.free;
end;             }

{
function TGitHub.ExtractSha(data : string) : string;
var
    JData : TJSONData;
    JObject : TJSONObject;
    jStr : TJSONString;
begin
    result := '';
    try
        try
            JData := GetJSON(Data);                         // requires a free
            JObject := TJSONObject(jData);                  // does not require a free
            if jObject.Find('sha', Jstr) then
                Result := jStr.AsString;
        except
            on E:Exception do Result := '';               // Invalid JSON or ID not present
        end;
    finally
        JData.Free;
    end;
end;        }

{
   "sha" : "fb1dfecbc50329c7bedfc9ae00ba522bc3bd8536",
   "node_id" : "MDY6Q29tbWl0Mzk0NTAzNTYxOmZiMWRmZWNiYzUwMzI5YzdiZWRmYzlhZTAwYmE1MjJiYzNiZDg1MzY=",
   "commit" : {
        "author" : {
                "name" : "davidbannon",
                "email" : "davidbannon@users.noreply.github.com",
                "date" : "2021-08-11T04:09:43Z"
        },
        "committer" : {
           "name" : "davidbannon",
           "email" : "davidbannon@users.noreply.github.com",
           "date" : "2021-08-11T04:09:43Z"
        },
        "message" : "initial upload",
        "tree" : {
           "sha" : "bc1518905982935199c8709ad0df564dd8499f50",
           "url" : "https://api.github.com/repos/davidbannon/tb_test/git/trees/bc1518905982935199c8709ad0df564dd8499f50"
        },
        "url" : "https://api.github.com/repos/davidbannon/tb_test/git/commits/fb1dfecbc50329c7bedfc9ae00ba522bc3bd8536",
        "comment_count" : 0,
        "verification" : {
           "verified" : false,
           "reason" : "unsigned",
           "signature" : null,
           "payload" : null
                    }
   },
   "url" : "https://api.github.com/repos/davidbannon/tb_test/commits/fb1dfecbc50329c7bedfc9ae00ba522bc3bd8536",
   "html_url" : "https://github.com/davidbannon/tb_test/commit/fb1dfecbc50329c7bedfc9ae00ba522bc3bd8536",
   "comments_url" : "https://api.github.com/repos/davidbannon/tb_test/commits/fb1dfecbc50329c7bedfc9ae00ba522bc3bd8536/comments",
   "author" : {
     "login" : "davidbannon",
     "id" : 6291248,
     "node_id" : "MDQ6VXNlcjYyOTEyNDg=",
     "avatar_url" : "https://avatars.githubusercontent.com/u/6291248?v=4",
     "gravatar_id" : "",
     "url" : "https://api.github.com/users/davidbannon",
     "html_url" : "https://github.com/davidbannon",
     "followers_url" : "https://api.github.com/users/davidbannon/followers",
     "following_url" : "https://api.github.com/users/davidbannon/following{/other_user}",
     "gists_url" : "https://api.github.com/users/davidbannon/gists{/gist_id}",
     "starred_url" : "https://api.github.com/users/davidbannon/starred{/owner}{/repo}",
     "subscriptions_url" : "https://api.github.com/users/davidbannon/subscriptions",
     "organizations_url" : "https://api.github.com/users/davidbannon/orgs",
     "repos_url" : "https://api.github.com/users/davidbannon/repos",
     "events_url" : "https://api.github.com/users/davidbannon/events{/privacy}",
     "received_events_url" : "https://api.github.com/users/davidbannon/received_events",
     "type" : "User",
     "site_admin" : false
   },
   "committer" : {
     "login" : "davidbannon",
     "id" : 6291248,
     "node_id" : "MDQ6VXNlcjYyOTEyNDg=",
     "avatar_url" : "https://avatars.githubusercontent.com/u/6291248?v=4",
     "gravatar_id" : "",
     "url" : "https://api.github.com/users/davidbannon",
     "html_url" : "https://github.com/davidbannon",
     "followers_url" : "https://api.github.com/users/davidbannon/followers",
     "following_url" : "https://api.github.com/users/davidbannon/following{/other_user}",
     "gists_url" : "https://api.github.com/users/davidbannon/gists{/gist_id}",
     "starred_url" : "https://api.github.com/users/davidbannon/starred{/owner}{/repo}",
     "subscriptions_url" : "https://api.github.com/users/davidbannon/subscriptions",
     "organizations_url" : "https://api.github.com/users/davidbannon/orgs",
     "repos_url" : "https://api.github.com/users/davidbannon/repos",
     "events_url" : "https://api.github.com/users/davidbannon/events{/privacy}",
     "received_events_url" : "https://api.github.com/users/davidbannon/received_events",
     "type" : "User",
     "site_admin" : false
   },
   "parents" : [
     {
       "sha" : "64c44175e2258b44bfa0a573ab1d33478d0ec610",
       "url" : "https://api.github.com/repos/davidbannon/tb_test/commits/64c44175e2258b44bfa0a573ab1d33478d0ec610",
       "html_url" : "https://github.com/davidbannon/tb_test/commit/64c44175e2258b44bfa0a573ab1d33478d0ec610"
     }
   ]
 }

*)














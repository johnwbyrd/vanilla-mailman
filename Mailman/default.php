<?php
if (!defined('APPLICATION'))
	exit();

$PluginInfo['Mailman'] = array(
		'Name' => 'Mailman',
		'Description' => 'Integrates Vanilla with Mailman 2.1 and the MysqlMemberships.py adaptor for Mailman.',
		'Version' => '0.01',
		'Author' => "John Byrd",
		'SettingsUrl' => '/dashboard/settings/mailman',
		'RequiredApplications' => array(
				'Vanilla' => '>=2.0.18'
		),
		'AuthorEmail' => 'jbyrd at giganticsoftware dot com',
		'AuthorUrl' => 'http://www.giganticsoftware.com',
		'MobileFriendly' => true,
		'RequiredPlugins' => false
);

class MailmanBaseClass extends stdClass
{

}

class MailmanUserOption extends MailmanBaseClass
{
	function __construct( $data )
	{
		$this->data = $data;
	}

	function SetName( $name )
	{
		$this->data['name'] = $name;
	}

	function GetName()
	{
		return $this->data['name'];
	}

	function GetShortDesc()
	{
		return $this->data['shortdesc'];
	}

	function GetLongDesc()
	{
		return $this->data['longdesc'];
	}

	function SetValue( $currentValue )
	{
		$this->data['value'] = $currentValue;
	}

	function GetValue()
	{
		return ( $this->data['value'] );
	}

	public $data;
}

/* We normally run the import function for batching a bunch of SQL commands for updating counts, because most of the code
 * for updating those counts already exists in the ImportModel class.  This class exists to tell the ImportModel to update
 * all the counts for all the discussion and comment fields.
 */
class MailmanImportModel extends ImportModel
{
	public function __construct()
	{
		if(!$this->Timer) {
			$NewTimer = TRUE;
			$this->Timer = new Gdn_Timer();
			$this->Timer->Start('');
		}

		$this->SQL = Gdn::SQL();
	}

	public function ImportExists($Table, $Column = '') {
		return FALSE;
	}

};

/* Lets a user save and restore mailman options from within vanilla. */
class MailmanUserOptionsManager extends MailmanBaseClass
{
	protected $userOptions = null;
	protected $data = null;

	public function __construct( $data )
	{
		$this->data = $data;

		$this->userOptions = array(
				new MailmanUserOption(
						array(
								'name' => 'nomail',
								'shortdesc' => T('Disable new discussion posts via e-mail'),
								'longdesc' => T("This option disables mail delivery to you when a new post occurs.
										If you disable mail delivery temporarily, don't forget to re-enable it when you come back;
										it will not be automatically re-enabled.")
						)
				),

				new MailmanUserOption(
						array(
								'name' => 'digest',
								'shortdesc' => T("Receive a daily digest of new activity"),
								'longdesc' => T("If you turn digest mode on, you'll get posts bundled together
										(usually one per day but possibly more on busy lists), instead of singly when they're sent.
										If digest mode is changed from on to off, you may receive one last digest.")
						)
				),
				new MailmanUserOption(
						array(
								'name' => 'ack',
								'shortdesc' => T("Acknowledge received e-mail"),
								'longdesc' => T("This setting causes you to receive acknowledgement mail
										when you send mail to the list.")
						)
				),
				new MailmanUserOption(
						array(
								'name' => 'plain',
								'shortdesc' => T("Send plain (non-MIME) message digests"),
								'longdesc' => T("Your mail reader may or may not support MIME digests.
										In general MIME digests are preferred, but if you have a problem reading them,
										enable this setting.")
						)
				),
				new MailmanUserOption(
						array(
								'name' => 'not_metoo',
								'shortdesc' => T("Don't copy my messages to myself"),
								'longdesc' => T("Ordinarily, you will not receive a copy of messages you post.
										If you want to receive a copy, disable this option.")
						)
				),

		);
	}

	protected function GetForeignTableName()
	{
		return $this->data['foreigntablename'];
	}

	protected function GetForeignEmailField()
	{
		return $this->data['foreignemailfield'];
	}

	public function GetOptions()
	{
		return $this->userOptions;
	}

	public function Update( &$optionToUpdate )
	{
		$nameToFind = $optionToUpdate->GetName();
		foreach ($this->userOptions as &$oneOption ) {
			if ( $nameToFind == $oneOption->GetName() ) {
				$oneOption->SetValue( $optionToUpdate->GetValue() );
				return;
			}
		}
	}

	public function Lookup( &$optionToFind )
	{
		$nameToFind = $optionToFind->GetName();
		foreach ($this->userOptions as &$oneOption ) {
			if ( $nameToFind == $oneOption->GetName() ) {
				return $oneOption;
			}
		}
		return null;
	}

	public function Read()
	{
		$Session = Gdn::Session();
		if ( is_object($Session->User) )
		{
			$email = $Session->User->Email;

			$Database = Gdn::Database();
			$SQL = $Database->SQL();

			// generate fields list
			$fieldsToQuery = "";
			$i = 0;
			$allOpts = $this->GetOptions();
			foreach ( $allOpts as $opt )
			{
				$fieldsToQuery .= $opt->GetName();
				$i++;
				if ( $i < count( $allOpts )) {
					$fieldsToQuery .= ', ';
				}
			}

			$Result = $SQL
			->Select( $fieldsToQuery )
			->From( $this->GetForeignTableName() )
			->Where( $this->GetForeignEmailField(), $email )
			->Get()
			->FirstRow();

			if ( $Result )
			{
				foreach ( $Result as $oneName => $oneValue ) {
					$this->Update( new MailmanUserOption(
							array(
									'name' => $oneName,
									'value' => ( $oneValue == 'Y' ? true : false )
							)
					)
					);
				}
				return true;
			}
		}
		return false;
	}

	public function Write()
	{
		$Session = Gdn::Session();
		if ( is_object($Session->User) )
		{
			$email = $Session->User->Email;

			$Database = Gdn::Database();
			$SQL = $Database->SQL();

			$allOpts = $this->GetOptions();

			$Result = $SQL->Update( $this->GetForeignTableName() );
			foreach ( $allOpts as $opt )
			{
				$Result = $Result->Set( $opt->GetName(), ($opt->GetValue() ? 'Y' : 'N'));
			}
			$Result = $Result->Where( $this->GetForeignEmailField(), $email )->Put();

			if ( $Result )
			{
				return true;
			}
		}
		return false;
	}
}

/**
 * Takes a user object, and writes out an achor of the user's name to the user's profile.
 * This overrides the function in functions.render.php, which prints out "Unknown" when we can't find
 * the right username.
 */
function UserAnchor($User, $CssClass = NULL, $Options = NULL) {
	static $NameUnique = NULL;
	if ($NameUnique === NULL)
		$NameUnique = C('Garden.Registration.NameUnique');

	if (is_array($CssClass)) {
		$Options = $CssClass;
		$CssClass = NULL;
	} elseif (is_string($Options))
	$Options = array('Px' => $Options);

	$Px = GetValue('Px', $Options, '');

	$Name = GetValue($Px.'Name', $User, T(''));
	$UserID = GetValue($Px.'UserID', $User, 0);
	$Text = GetValue('Text', $Options, htmlspecialchars($Name)); // Allow anchor text to be overridden.

	$Attributes = array(
			'class' => $CssClass,
			'rel' => GetValue('Rel', $Options)
	);
	if (isset($Options['title']))
		$Attributes['title'] = $Options['title'];
	$UserUrl = UserUrl($User,$Px);
	return '<a href="'.htmlspecialchars(Url($UserUrl)).'"'.Attribute($Attributes).'>'.$Text.'</a>';
}

class Mailman extends Gdn_Plugin
{

	/* The e-mail address that a user attempting to log in just entered. */
	private $EmailEntered;
	/* The user we were able to look up from the email that the user typed in, if we found it successfully */
	private $UserEntered;
	/* The password that the user entered */
	private $PasswordEntered;

	/* The user's password as we looked it up in mailman database */
	private $PasswordMailman;
	/* The user's full name as we looked it up the mailman database */
	private $FullNameMailman;

	/* The name of the SQL table that contains mailman info (usually "GDN_mailman_mysql") */
	private $ForeignTableName;
	/* The name of the SQL field that contains the mailman password (usually "password") */
	private $ForeignPasswordField;
	/* The name of the SQL field that contains the email addres for the user (usually "address") */
	private $ForeignEmailField;
	/* The name of the SQL field that contains the full name of the user (usually "name") */
	private $ForeignFullNameField;
	/* The name of the SQL field that contains the name of the mailman email address that email should be sent to from vanilla when
	 * it's posted to the forum -- usually some kind of forum->gateway email address, should be set up as a "hide" user in the mailman
	 * list in question
	 */
	private $ForeignListEmailAddress;


    public function Base_Render_Before(&$Sender) {

            if(strpos($_SERVER['REQUEST_URI'],'termsofservice') == true ||
                    strpos($_SERVER['REQUEST_URI'],'emailavailable') ||
                    strpos($_SERVER['REQUEST_URI'],'usernameavailable')) {

            }

            else if(Gdn::Session()->UserID == 0 &&
                    strpos($_SERVER['REQUEST_URI'],'entry') == false) {

                    Redirect('entry');
            }
    }

	/* A comment has been saved.  We need to pull the details out of the comment and generate an email
	 * message with those details and send it on to mailman.
	*/
	public function CommentModel_AfterSaveComment_Handler($Sender,$Args)
	{
		$this->InitializeConstants();

		// First get the comment ID out of the arguments
		$CommentID = $Args[CommentID];

		// We could pull the discussion ID out of the FormPostValues but it's probably safer not to trust it...
		// Get DiscussionID and the UserID out of the Comment database
		$Database = Gdn::Database();
		$SQL = $Database->SQL();

		$CommentRecord = $SQL->Select("DiscussionID, InsertUserID, Body, Format")->
		From("Comment")->
		Where("CommentID", $CommentID)->
		Get()->
		FirstRow();

		if ( !isset( $CommentRecord ))
			throw new Gdn_UserException("Could not find comment ID $CommentID.");

		$DiscussionID = $CommentRecord->DiscussionID;
		$UserID = $CommentRecord->InsertUserID;
		$Body = $CommentRecord->Body;
		$Format = $CommentRecord->Format;

		// Now we've got the discussion ID... Go to the discussion database and get the EmailMessageID out of there
		$DiscussionRecord = $SQL->Select("EmailMessageID, Name")->
		From("Discussion")->
		Where("DiscussionID", $DiscussionID)->
		Get()->
		FirstRow();

		if (!isset( $DiscussionRecord ))
			return;

		$InReplyTo = $DiscussionRecord->EmailMessageID;
		// That will be the References: and/or In-Reply-To: header
		$Subject = $DiscussionRecord->Name;

		// Get the user's email address out of the User database
		$UserRecord = $SQL->Select("Name, Email")->
		From("User")->
		Where("UserID", $UserID )->
		Get()->
		FirstRow();

		if ( !isset($UserRecord))
			return;

		$Name = $UserRecord->Name;
		$From = $UserRecord->Email;

		// Synthesize the message
		$Domain = array_pop( explode('@', $From ));
		$To = $this->ForeignListEmailAddress;

		$MessageID .= uniqid($CommentID, TRUE);
		$MessageID .= '@';
		$MessageID .= $Domain;

		$this->SaveCommentInfo( $CommentID, $MessageID, $Body, $From );

		$Email = new Gdn_Email();
		$Email->From($From, $Name);
		$Email->To($To);
		/* This message ID is going to get munged by Mailman when it resends */
		$Email->AddHeader("Message-ID", $MessageID );
		/* We hope this one is not however */
		$Email->AddHeader("X-Original-Message-ID", $MessageID );
		$Email->AddHeader("X-Original-Sender", $From );
		$Email->AddHeader("References", $InReplyTo);
		$Email->Subject("Re: " . $Subject);
		$Email->Message($Body);

		$this->TrySendingEmail( $Email );
	}

	/** Does the Mailman database exist?
	 */
	protected function DoesMailmanDatabaseExist()
	{
		$Database = Gdn::Database();
		$SQL = $Database->SQL();
		$all_tables = $SQL->FetchTables();
			
		return in_array( $this->GetMailmanDatabaseName(), $all_tables );
	}
	
	public function DiscussionController_BeforeDiscussionDisplay_Handler( &$Sender, &$Args )
	{
		/* If the Author could not be found, then poke in a reasonable facsimile thereof by creating a false Author. */
		$t = 1;
	}

	// public function PostController_AfterDiscussionSave_Handler( $Sender, $Args )
	public function DiscussionModel_AfterSaveDiscussion_Handler($Sender,$Args)
	{
		$this->InitializeConstants();

		$Discussion = $Args['Discussion'];

		$DiscussionID = $Discussion->DiscussionID;
		$Subject = $Discussion->Name;
		$Body = $Discussion->Body;
		$Format = $Discussion->Format;
		$From = $Discussion->InsertEmail;
		$Domain = array_pop( explode('@', $From ));
		$To = $this->ForeignListEmailAddress;

		$MessageID .= uniqid($DiscussionID, TRUE);
		$MessageID .= '@';
		$MessageID .= $Domain;

		$this->SaveDiscussionInfo( $DiscussionID, $MessageID, $Body, $From );

		$Email = new Gdn_Email();
		$Email->From($From, $From);
		$Email->To($To);
		/* This message ID is going to get munged by Mailman when it resends */
		$Email->AddHeader("Message-ID", $MessageID );
		/* We hope this one is not however */
		$Email->AddHeader("X-Original-Message-ID", $MessageID );
		$Email->AddHeader("X-Original-Sender", $From );
		$Email->Subject($Subject);
		$Email->Message($Body);

		$this->TrySendingEmail($Email);
	}

	/* Called anytime a signin is attempted.  Need to check user against mailman database and update relevant fields in vanilla. */
	public function EntryController_SignIn_Handler($Sender, $Args)
	{
		if ($Sender->Form->IsPostBack()) {
			$Sender->Form->ValidateRule('Email', 'ValidateRequired', sprintf(T('%s is required.'), T('Email/Username')));
			$Sender->Form->ValidateRule('Password', 'ValidateRequired');

			// Check the user.
			if ($Sender->Form->ErrorCount() == 0) {

				$this->InitializeConstants();

				if ( !( $this->DoesMailmanDatabaseExist()) )
				{
					$Sender->Form->AddError("The mailman database " .
							$this->GetMailmanDatabaseName() .
							" could not be found!  Check the database name in the Vanilla mailman plugin.");
					return;
				}

				$this->EmailEntered = filter_var( $Sender->Form->GetFormValue('Email'), FILTER_SANITIZE_EMAIL );
				$this->PasswordEntered = filter_var( $Sender->Form->GetFormValue('Password'), FILTER_SANITIZE_MAGIC_QUOTES );
				$this->UserEntered  = Gdn::UserModel()->GetByEmail( $this->EmailEntered );

				if (!($this->UserEntered ))
					$this->UserEntered = Gdn::UserModel()->GetByUsername($this->EmailEntered);

				$this->MailmanHandleLoginAttempt();
				return;
			}
		}
	}
	
	/** Returns the name of the table storing Mailman information.
	 *
	 * @return string The name of the table (usually GDN_mailman_mysql)
	 */
	protected function GetMailmanDatabaseName()
	{
		$this->InitializeConstants();
		$Database = Gdn::Database();
		return $Database->DatabasePrefix . $this->ForeignTableName;
	}

	protected function GetUserOptionsManager()
	{
		$this->InitializeConstants();
		$mm = new MailmanUserOptionsManager(
				array(
						'foreigntablename' => $this->ForeignTableName,
						'foreignemailfield' => $this->ForeignEmailField
				)
		);
		return $mm;
	}
	
	protected function InitializeConstants()
	{
		$this->UpdateTableAndFieldNames();
	}

	/** Copies the password and user's full name from the mailman database into Vanilla.
	 */
	protected function MailmanCopyInPassword()
	{
		$um = new UserModel();
	
		if ( $this->PasswordMailman )
		{
			// he might have been previously banned, unban him
			$um->SetField( $this->UserEntered->UserID, 'Banned', 0 );
			$um->SetField( $this->UserEntered->UserID, 'Password', $this->PasswordMailman );
		}
	
		if ( $this->FullNameMailman )
		{
			$um->SetField( $this->UserEntered->UserID, 'Name', $this->FullNameMailman );
		}
	
		unset( $um );
	}

	protected function MailmanCreateNewUser()
	{
		// Apparently we don't need to take the spaces out of the user names
		// $UserData['Name'] = preg_replace('/\s+/', '', $this->FullNameMailman );
			
		$UserData['Name'] = $this->FullNameMailman;
		if ( ! ( $UserData['Name'] ) )
		{
			// come on, we need something we can call a name
			$UserData['Name'] = $this->EmailEntered;
		}
			
		$UserData['Password'] = $this->PasswordMailman;
		$UserData['Email'] = $this->EmailEntered;
		$UserData['CountNotifications'] = "0";
		// This data came out of mailman, so don't reconfirm the e-mail address
		$UserData['Confirmed'] = TRUE;
			
		$UserModel = new UserModel();
		$UserID = $UserModel->Save($UserData,
				array(
						'ActivityType' => 'Join',
						'CheckExisting' => TRUE,
						'NoConfirmEmail' => TRUE
				)
		);
	
		// Add the user to the default role(s).  We don't create moderators by default.
		if ($UserID) {
			$UserModel->SaveRoles($UserID, C('Garden.Registration.DefaultRoles'));
	
			// This is the user we just created.
			$this->UserEntered  = Gdn::UserModel()->GetByEmail( $this->EmailEntered );
			$UserModel->ClearCache($UserID, array('user'));
		}
		else
		{
			throw new Gdn_UserException("Could not create corresponding user in Vanilla database based on existing mailman entry.");
		}
	}
	
	protected function MailmanDisableUserIfExists()
	{
		if (! ( $this->UserEntered ))
			return; // couldn't even find the user in the db, don't worry
			
		// shouldn't be here, ban him
		$um = new UserModel();
		$um->SetField( $this->UserEntered->UserID, 'Banned', 1 );
		unset( $um );
	}	

	protected function MailmanHandleLoginAttempt()
	{
		// We don't actually validate logins; we let Vanilla do that.  All we do is extract the current password from
		// mailman into vanilla.
		$Database = Gdn::Database();
		$SQL = $Database->SQL();
	
		$Result = $SQL
		->Select( $this->ForeignFullNameField . ", " . $this->ForeignPasswordField)
		->From( $this->ForeignTableName )
		->Where( $this->ForeignEmailField, $this->EmailEntered )
		->Get()
		->FirstRow();
			
		if ( $Result )
		{
			$this->PasswordMailman = $Result->password;
			$this->FullNameMailman = $Result->name;
		}
			
		// If there is no corresponding user in Mailman, disable the user's login permissions and give up
		if ( !( $this->PasswordMailman ))
		{
			$this->MailmanDisableUserIfExists();
			return;
		}
			
		// If the corresponding user does not exist in Vanilla, create them
		if ( !( $this->UserEntered ))
		{
			$this->MailmanCreateNewUser();
		}
			
		// Now we have a matching user in Vanilla.  Copy the password and permissions to their account.
		$this->MailmanCopyInPassword();
	}
	
	public function PluginController_Mailman_Create(&$Sender)
	{
		$Sender->Permission('Garden.Settings.Manage');
		$this->Dispatch($Sender, $Sender->RequestArgs);
	}

	/* Called when the user decides to edit their account.  Need to render custom mailman flags and fields. */
	public function ProfileController_EditMyAccountAfter_Handler( $Sender, $Args )
	{
		$Sender->AddCssFile('plugins/Mailman/mailman.css');

		echo '<li class="User-EmailSettings">';
			
		echo $Sender->Form->Label(T('Email Settings'), T('Email Settings'));
			
		$mm = $this->GetUserOptionsManager();
		if ( ! $mm->Read() )
			return; // don't bother, we can't even figure out who this is

		echo '<table id="mail-options">';

		$opts = $mm->GetOptions();
		foreach ( $opts as $opt ) {
			echo '<div class="mail-option-',  $opt->getname(), '">', "\n";
			echo '<tr class="mail-options-row">';

			$checkedbox = null;
			if ( $opt->GetValue() ) {
				$checkedbox = array( 'checked' => 'true');
			}

			echo '<td class="mail-option-column mail-option-checkbox-', $opt->GetName(), '">';
			echo $Sender->Form->CheckBox( $opt->GetName(),
					$opt->GetShortDesc(),
					$opt->GetValue() ? array( 'checked' => 'true') : null
			);
			echo '</td>';

			echo '<td class="mail-option-column mail-option-checkbox-', $opt->getname(), '-longdescription">',
			$opt->getlongdesc(), '</td>', "\n";

			echo '</tr>';
			echo '</div>', "\n";
		}
			
		echo '<table>';
		echo '</li>';
	}

	// Write the extra information about this discussion into the custom comment fields.
	public function SaveCommentInfo( $CommentID, $MessageID, $Body, $From )
	{
		// First, get the information out of the fields and verify that they're NULL
		$Database = Gdn::Database();
		$SQL = $Database->SQL();

		$Result = $SQL->Select()->
		From( "Comment" )
		->Where( "CommentID", $CommentID )
		->Get()
		->FirstRow();

		// if we couldn't find that discussion ID, then die
		if ( !isset( $Result ) )
			return;

		// maybe we've already filled into this info; don't do it again if so
		if ( $Result->MessageID ||
				$Result->SenderEmailAddress ||
				$Result->EmailOriginalMessage )
			return;

		$Result = $SQL->Update("Comment")->
		Set("EmailMessageID", $MessageID)->
		Set("EmailOriginalMessage", $Body)->
		Set("SenderEmailAddress", $From)->
		Where("CommentID", $CommentID)->
		Put();
	}

	// Write the extra information about this discussion into the custom discussion fields.
	public function SaveDiscussionInfo( $DiscussionID, $MessageID, $Body, $From )
	{
		// First, get the information out of the fields and verify that they're NULL
		$Database = Gdn::Database();
		$SQL = $Database->SQL();

		$Result = $SQL->Select()->
		From( "Discussion" )
		->Where( "DiscussionID", $DiscussionID )
		->Get()
		->FirstRow();

		// if we couldn't find that discussion ID, then die
		if ( !isset( $Result ) )
			throw new Gdn_UserException("Could not find discussion ID: $DiscussionID.");

		// maybe we've already filled into this info; don't do it again if so
		if ( $Result->MessageID ||
				$Result->SenderEmailAddress ||
				$Result->EmailOriginalMessage )
			return;

		$Result = $SQL->Update("Discussion")->
		Set("EmailMessageID", $MessageID)->
		Set("EmailOriginalMessage", $Body)->
		Set("SenderEmailAddress", $From)->
		Where("DiscussionID", $DiscussionID)->
		Put();
	}
	
	public function SettingsController_Mailman_Create($Sender)
	{
		$Sender->Permission('Garden.Settings.Manage');
	
		/* Only initialize the tables structure when we take a look at the settings for mailman.  This should be ok but someone
		 * still might complain... meh
		 */
		$this->UpdateTablesStructure();
		$Config = new ConfigurationModule($Sender);
	
		$Config->Initialize(array(
	
				'Plugins.Mailman.ListEmailAddress' => array(
						'Type' => 'string',
						'Control' => 'TextBox',
						'Default' => 'yourlist@yourlistdomain.com',
						'Description' => "The e-mail address to which users send e-mails, which are in turn redistributed by Mailman.  The list's
						e-mail address."
				),
	
				'Plugins.Mailman.Table' => array(
						'Type' => 'string',
						'Control' => 'TextBox',
						'Default' => 'mailman_mysql',
						'Description' => 'The name of the foreign MySQL table from which the password should be used.  This must be a MysqlMembership
						"flat" format table, and it must be stored in the Vanilla database.  The GDN_ prefix will be appended to the name of this
						file before using, so don\'t include it here.'
				),
					
				'Plugins.Mailman.PasswordField' => array(
						'Type' => 'string',
						'Control' => 'TextBox',
						'Default' => 'password',
						'Description' => 'The name of the field from the above table that contains the password.  Will be
						copied directly into the Vanilla password field	when the user attempts to log in.'
				),
					
				'Plugins.Mailman.UserEmailField' => array(
						'Type' => 'string',
						'Control' => 'TextBox',
						'Default' => 'address',
						'Description' => 'The name of the field from the above table that contains the email address for each user.  Will be
						joined to the native Vanilla database in order to find whether the user should be granted permission.'
				),
	
				'Plugins.Mailman.FullNameField' => array(
						'Type' => 'string',
						'Control' => 'TextBox',
						'Default' => 'name',
						'Description' => 'The name of the field from the above table that contains the full name for each user.'
				)
					
		));
	
		$Sender->AddSideMenu('settings/mailman');
		$Sender->SetData('Title', T('Mailman'));
		$Config->RenderAll();
	}

	/* Called by the UsefulFunctions plugin every 5 minutes to update comment and discussion counts and totals. */
	public function Tick_Every_5_Minutes_Handler()
	{
		$this->InitializeConstants();
		$this->UpdateCounts();
		$this->UpdateInsertUserIDs();
	}

	protected function TrySendingEmail( $Email )
	{
		try {
			$Email->Send();
			$Emailed = TRUE; // similar to http 200 OK
		} catch (phpmailerException $pex) {
			if ($pex->getCode() == PHPMailer::STOP_CRITICAL)
				$Emailed = FALSE;
			else
				$Emailed = FALSE;
		} catch (Exception $ex) {
			$Emailed = FALSE; // similar to http 5xx
		}
	}

	/** Update counts for discussions and comments.  This includes the first and last comment ID fields in the Discussion
	 * database as well as comment and discussion counts.  This should be done when new messages from Mailman have been imported
	 * into the database.
	 */
	protected function UpdateCounts()
	{
		// This option could take a while so set the timeout.
		set_time_limit(60*5);

		$import = new MailmanImportModel();

		// Define the necessary SQL.
		$Sqls = array();

		$Sqls['Discussion.LastCommentID'] = $import->GetCountSQL('max', 'Discussion', 'Comment');

		$Sqls['Discussion.DateLastComment'] = "update :_Discussion d
				left join :_Comment c
				on d.LastCommentID = c.CommentID
				set d.DateLastComment = coalesce(c.DateInserted, d.DateInserted)";

		$Sqls['Discussion.LastCommentUseID'] = "update :_Discussion d
				join :_Comment c
				on d.LastCommentID = c.CommentID
				set d.LastCommentUserID = c.InsertUserID";

		$Sqls['Discussion.FirstCommentID'] = $import->GetCountSQL('min', 'Discussion', 'Comment', 'FirstCommentID', 'CommentID');
		$Sqls['Discussion.CountComments'] = $import->GetCountSQL('count', 'Discussion', 'Comment');

		$Sqls['UserDiscussion.CountComments'] = "update :_UserDiscussion ud
				set CountComments = (
				select count(c.CommentID)
				from :_Comment c
				where c.DiscussionID = ud.DiscussionID
				and c.DateInserted <= ud.DateLastViewed)";

		$Sqls['Category.CountDiscussions'] = $import->GetCountSQL('count', 'Category', 'Discussion');
		$Sqls['Category.CountComments'] = $import->GetCountSQL('sum', 'Category', 'Discussion', 'CountComments', 'CountComments');

		$Database = Gdn::Database();
		$SQL = $Database->SQL();

		$Keys = array_keys($Sqls);
		for($i = 0; $i < count($Keys); $i++) {
			$Sql = $Sqls[$Keys[$i]];
			$import->Query($Sql);
		}

		return TRUE;
	}
	
	protected function UpdateTableAndFieldNames()
	{
		$this->ForeignTableName = C('Plugins.Mailman.Table', 'mailman_mysql');
		$this->ForeignPasswordField = C('Plugins.Mailman.PasswordField', 'password');
		$this->ForeignEmailField = C('Plugins.Mailman.UserEmailField', 'address');
		$this->ForeignFullNameField = C('Plugins.Mailman.FullNameField', 'name');
		$this->ForeignListEmailAddress = C('Plugins.Mailman.ListEmailAddress', 'yourlist@yourlistdomain.com');
	}
	
	/** Adds Mailman specific fields to the Comments and Discussions tables. */
	protected function UpdateTablesStructure()
	{
		$Database = Gdn::Database();
		$SQL = $Database->SQL();
		$Construct = $Database->Structure();
	
		$Construct->Table('Discussion')
		->Column('EmailMessageId', 'varchar(8192)', TRUE, 'key' )
		->Column('EmailOriginalMessage', 'text', TRUE )
		->Column('SenderEmailAddress', 'varchar(1024)', TRUE, 'key' )
		->Column('Hidden', array('Yes','No'), TRUE )
		->Set( FALSE, FALSE );
	
		$Construct->Table('Comment')
		->Column('EmailMessageId', 'varchar(8192)', TRUE, 'key' )
		->Column('EmailOriginalMessage', 'text', TRUE )
		->Column('SenderEmailAddress', 'varchar(1024)', TRUE, 'key' )
		->Column('Hidden', array('Yes','No'), TRUE )
		->Set( FALSE, FALSE );
	}
	
	protected function UpdateInsertUserIDs()
	{
		$Database = Gdn::Database();
		$SQL = $Database->SQL();
		
		/* Note: don't escape the set clause, as we're setting the value to some value in the right part of 
		 * the join
		 */
		$Result = $SQL->Update('Discussion d')
		->Join('User u', 'u.Email = d.SenderEmailAddress', 'left')
		->Set('d.InsertUserID', 'u.UserID', FALSE) 
		->Where('d.InsertUserID', '0')
		->Put();
		
		$Result = $SQL->Update('Comment c')
		->Join('User u', 'u.Email = c.SenderEmailAddress', 'left')
		->Set('c.InsertUserID', 'u.UserID', FALSE)
		->Where('c.InsertUserID', '0')
		->Put();

	}
	
	/* Called when the user clicks Save on User preferences form.  Need to save mailman settings. */
	public function UserModel_AfterSave_Handler($Sender)
	{
		$mm = $this->GetUserOptionsManager();
		$allOpts = $mm->GetOptions();

		// update fields from form

		$updateWorked = false;
		$eventArgs = $Sender->EventArguments;
		if ( is_array( $eventArgs ))
		{
			$formpost = $eventArgs['FormPostValues'];
			if ( is_array( $formpost )) {
				foreach ( $allOpts as &$opt ) {
					$name = $opt->GetName();
					$value = $formpost[ $name ];
					$opt->SetValue( $value );
					$mm->Update( $opt );
					$updateWorked = true;
				}
			}
		}
		if ( ! $updateWorked )
			return false;

		if ( $mm->Write())
		{
			return true; // it works or it doesn't
		}
		return false;
	}

	/* Called when the user changes their password.  If the form has information about the old and new password,
	 * we need to pull out the new password and push it to mailman.
	*/
	public function UserModel_BeforeSave_Handler( $Sender, $Args )
	{
		$this->InitializeConstants();

		// Let's make sure that the user really changed their password here
		$FormPostValues = $Args['FormPostValues'];
		if ( !isset( $FormPostValues ))
			return;

		$Action = $FormPostValues['Change_Password'];
		if ( $Action != "Change Password")
			return;

		$Password = $FormPostValues['Password'];
		if (!isset($Password))
			return;

		// Get the e-mail address of the current user
		$User = $Args['User'];
		if (!isset( $User ))
			return;

		$Email = $User['Email'];
		if (!isset( $Email ))
			return;

		// Update the user account in mailman with the unencrypted password
		$Database = Gdn::Database();
		$SQL = $Database->SQL();

		$Result = $SQL->
		Update( $this->ForeignTableName )->
		Set( $this->ForeignPasswordField, $Password )->
		Where( $this->ForeignEmailField, $Email )->
		Put();
	}
}

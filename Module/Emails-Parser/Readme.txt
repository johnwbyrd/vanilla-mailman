Thanks for using the Plugin.

Please go to the settings page in the dashboard for this plugin.
It is always a good idea to disable the plugin and then update to new version, and then re-enable, and check settings.

Please make a monetary donation if you use this plugin on your site. 


A donation link is in the dashboard settings. 

It took weeks to develop and more weeks to debug and upgrade.  

Perhaps a token contribution of $10.

regards,

Peregrine.



YOU can change css -  see CSS tutorials on the web

YOU can change wording by changing the definitions within the locale directory of the plugin,  
   See the documentation for localization on the vanilla forums website.


Steps to ensuring a better response to any questions, in this order.

1.  make a donation
2.  ask question
3.  repeat as necessary.

Like the plugin, but want a new feature or a modification.
1. send in your donation for the existing plugin.
2. specify what you want, and how much you will pay for the modification on the forum.


If you made a donation, I will try to answer your questions.  If your pledge amount for a new feature is something I can do based on the amount you want to pay, I will do it.

 if you use vanilla 2.0.18.4 and if you want badge to updates upon a user signin, since there is no event.

    you can change in /applications/dashboard/controllers/entrycontroller.php

about 4 or 5 places.

    From
   
    Gdn::Session()->Start($UserID);

    this to this

    Gdn::Session()->Start($UserID);
    Gdn::UserModel()->FireEvent('AfterSignIn');


-------------------------------------------------------------------------------------



Also badges will update when your profile is viewed However,You may need to click on the profile twice if the badges don't show.


Also to add special badges in config.php


  // add up to 3 special badges
        
          
          naming convention   NAME is name of Badge   1,2,3,4,5,6,7,8.9  should be the actual userid's that you want to have badge.
          
          $Configuration['Plugins']['PeregrineBadges']['SpecialBadgeA'] = array('NAME',1,2,3,4,5,6,7,8.9);
          
         
         
          badge A
        
       
           e.g.  if you userids  3 , 7, 9, 12  to get a badge called "RedHerring"  you would change it to 
       
             $Configuration['Plugins']['PeregrineBadges']['SpecialBadgeA'] = array('RedHerring',3,7,9,12);
          
          
           for Badge B  (name of badge is RedHerring100  and userids 2 and 4 were assigned
        
       
          $Configuration['Plugins']['PeregrineBadges']['SpecialBadgeB'] = array('RedHerring100',2,4);
         
        
        
           e.g.  if you userids  5,10,12 to get a badge called "Coffee"  you would change it to 
          
          $Configuration['Plugins']['PeregrineBadges']['SpecialBadgeC'] = array('Coffee',5,10,12);
          
          
          
          the name of the 3 images of the special badges is sba.png for SpecialBadgeA,  sbb.png for SpecialBadgeB  and sbc.png for SpecialBadgeC
          
      
          

          
          

*input datas;
Proc import Datafile="/folders/myfolders/STAT621/Players.csv"
    DBMS=CSV
	OUT=WORK.Players;
	GETNAMES=YES;
RUN;

Proc contents data=players;
run;

Proc import Datafile="/folders/myfolders/STAT621/player_data.csv"
    DBMS=CSV
	OUT=WORK.player_data;
	GETNAMES=YES;
RUN;

Proc contents data=player_data;
run;

Proc import Datafile="/folders/myfolders/STAT621/Seasons_Stats.csv"
    DBMS=CSV
	OUT=WORK.Seasons_Stats;
	GETNAMES=YES;
RUN;

Proc contents data=Seasons_Stats;
run;


*tidy up, change formats and modify units;
**************************************************************************************************

******************************************Player_data file*****************************************;
Proc sort data=player_data;
 by name;
run;

Data Player_data1;
 set player_data;
 *set year to date format;
 Year_start=mdy(1,1,year_start);
 Year_end=mdy(1,1,year_end);
 birth_date=datepart(birth_date);
 format year_start year4. year_end year4. birth_date MMDDYY10.;
 *uniform the name variable to player;
 rename name=player;
 *spliting the height to feet and inch;
 feet=input(scan(height,1,"-"),f1.);
 inch=input(scan(height,2,"-"),f2.);
 Drop height;
Run;

Data Player_data2;
  set player_data1;
  * putting the height together, and calculate to cm;
  Height_cm= (feet*12+inch)*2.54;
  drop feet inch;
  *calculate the weight from lb to kg;
  weight_kg=round(weight*0.453592,0.01);
  Drop weight;
run;

***********************************************************************************************
******************************************players file*****************************************;
Proc sort data=players;
by player;
run;

Data Players1;
  set players;
  * var1 is the counting var with no meaning;
  drop var1;
  *format born from num to date;
  born=mdy(1,1,born);
  format born Year4.;
  rename height=height_cm weight=weight_kg;
run;


*****************************************************************************************************
******************************************seasons_stats file*****************************************;
proc sort data=seasons_stats;
by player;
run;
*deleting empty variables, observations, rename;
data seasons_stats1;
  set seasons_stats;
  *delete empty obs;
  if player="" then delete;
  *delete empty vars;
  drop var1 PER _3PAr ORB_ DRB_ TRB_ AST_ STL_ BLK_ TOV_ USG_ blanl blank2 DBPM BPM VORP _3P _3PA STL BLK 
  ORB DRB OBPM TOV _3P_;
  *get the names of var meanningful;
  rename year=season POS=position Tm=Team G=Games TS_=TrueShootingPercentage MP = MinutesPlayed GS = GamesStarted
         FTr=FreeThrowRate OWS=OffensiveWinShares DWS=DefensiveWinShares WS=WinShares WS_48=WinSharesPer48Min
         FG=FieldGoals FGA=FieldGoalAttempts FG_=FieldGoalPercentage _2P_=_2P_Percentage 
         eFG_=EffectiveFieldGoalPercentage FT=FreeThrows FTA=FreeThrowAttempts FT_=FreeThrowPercentage
         AST=Assists PF=PersonalFouls PTS=Points TRB=TotalRebounds;
run;

proc contents data=seasons_stats1;
run;

*deleted 67 obs (24691-24624), 53 to 26 vars;
*readded games started and minutes played variables

*formating;
data seasons_stats2;
 set seasons_stats1;
 *format seasons to date;
 season=mdy(1,1,season);
 format season year4.;
run;


********************************************************************************************************
**********************************merging table player_data and players*********************************;
Proc sort data=player_Data2;
 by player;
run;
Proc sort data=players1;
 by player;
run;

*join two tables 
create var play_name with players in both table
(there are incomplete names and names with * in player1),
the weight and the height in two tables are a little different,
fill in the college info;

Proc sql;
  create table Player_full as
   select players1.player as player1, 
         player_data2.player as player2,
     case when player2 contains player1
       then player2
       when player1 contains player2
       then player2
       when player1 is missing
       then player2
       else player1
       end as player_name,
     birth_date, born, birth_city, Birth_state, year_start, year_end, position,
   Case when players1.height_cm=.
        then player_data2.height_cm
        else players1.height_cm
        end as height_cm, 
   case when players1.weight_kg=.
        then player_data2.weight_kg
        else players1.weight_kg
        end as weight_kg,
    case when players1.collage=""
       then player_data2.college
       else players1.collage
       end as college
    from Players1 right join player_data2
    on players1.player= player_data2.player;
quit;

*drop the dup vars;
data Player_final;
   set player_full;
   drop player1 player2 born;
   rename player_name=player;
   run;

*******************************************ADD VARIABLES NEEDED*****************************************

*calculate the vars needed;
data player_final1;
   set player_final;
   start_age=round(((year_start-birth_date-int(int((year_start-birth_date)/365)/4))/365),1);
   Career_length=int((year_end-year_start-int(int((year_end-year_start)/365)/4))/365);
   BMI=weight_kg/((Height_cm/100)**2);
   *add variable swing man;
   if length(position)=3 then do;
   Swing_man="Yes";
   end;
   if length(position)=1 then do;
   Swing_man="No";
   end;
   if position="" then do;
   Swing_man="NA";
   end;
   *edit position, switch position c-f to f-c and g-f to f-g;
   if position="C-F" then position="F-C";
   else if position="G-F" then position="F-G";
run;

*********************more data set editing to perform analysis***********************************;
*********************credit: Sean****************************************************************;


*********************adding censor column to player_final1 data set**********;
data player_final1_edit;
	set player_final1;
	censor = 1;

	
proc print data = seasons_stats2 (obs = 50);


****************getting counts and averages for relevant columns in the season stats data set************;

proc sql;
create table player_seasons_total1 as
 select player, season, games, points, trueshootingpercentage, freethrowrate, assists, 
 freethrowpercentage, team
  from seasons_stats2
   order by player;
quit;

	
proc sql;
  create table player_season_count as
  select player, count(season) as seasons, avg(games) as avg_games, avg(points) as avg_points,
  avg(trueshootingpercentage) as avg_shootingpercentage, avg(freethrowrate) as avg_freethrowrt,
  avg(assists) as avg_assists, avg(freethrowpercentage) as avg_freethrowpct, count(distinct team) as team_count
 from player_seasons_total1
  group by player;
quit;


*******************merge the edited player data set and seasons data set together********************;
data combined3;
	merge player_final1_edit player_season_count;
	by player;
	
*******************histograms to determine covariate distributions/level cutoffs***********************************;

*points;
PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_points;

*games;
PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_games;


*true shooting percentage;
PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_shootingpercentage;



PROC UNIVARIATE DATA = player_season_count;
var avg_shootingpercentage;
output out=shootpct pctlpre=shootpctfifths pctlpts=20,40,60,80; 


proc print data = shootpct;


*assists;
PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_assists;


*free throw percentage;
PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_freethrowpct;


PROC UNIVARIATE DATA = player_season_count;
var avg_freethrowpct;
output out=shootftpct pctlpre=shootftpctfifths pctlpts=20,40,60,80; 


proc print data = shootftpct;
	
	
*******************turn all relevant variables into categorical variables****************************;
	
data player_career_length;
	set combined3;
	* bmi categories determined by official bmi chart;
	if bmi lt 18.5 then bmi_recode = 'Underweight';
	else if bmi ge 18.5 and bmi lt 25 then bmi_recode = 'Normal';
	else if bmi ge 25 and bmi lt 30 then bmi_recode = 'Overweight';
	else if bmi ge 30 then bmi_recode = 'Obese';
	
	/*
	average number of games levels:
	0 to 24%	0 - 22.5000
	25 to 49% 	22.5 - 43.5714
	50 to 74% 	43.5714 - 59.4211
	75 to 100%	59.4211 and up
	50 and 75 has been combined
	*/

	if avg_games lt 22.5000 and avg_games ge 0 then average_games = 'low';
	else if avg_games lt 43.5714 and avg_games ge 22.5000 then average_games = 'medium';
	else if avg_games ge 43.5714 then average_games = 'high';



	*average shooting percentage levels: 
	0 to 20th percentile: very low (0 - .454)
	21st to 40th percentile: low (.454 - .49018)	
	41st to 60th percentile: medium (.49018 - .51344)
	61st to 80th percentile: high	(.51344 - .53833)
	81st to 100 percentile: very high (.53833 - 1);
	
	if avg_shootingpercentage le .454 and avg_shootingpercentage ge 0 then average_shootingpercentage = 'very low';
	else if avg_shootingpercentage le 0.49018 and avg_shootingpercentage gt .454 then average_shootingpercentage = 'low';
	else if avg_shootingpercentage le 0.51344 and avg_shootingpercentage gt 0.49018
	then average_shootingpercentage = 'medium';
	else if avg_shootingpercentage le 0.53833 and avg_shootingpercentage gt 0.51344
	then average_shootingpercentage = 'high';
	else if avg_shootingpercentage gt 0.53833 then average_shootingpercentage = 'very high';
	
	/*
	Quantiles for assists column
		95%	264.667
		90%	199.091
		75% Q3	104.273
		50% Median	42.000
		25% Q1	11.000
	*/
	
	if avg_assists le 11.000 and avg_assists ge 0 then average_assists = '25pct';
	else if avg_assists le 42.000 and avg_assists gt 11.000 then average_assists = 'median';
	else if avg_assists le 104.273 and avg_assists gt 42.000 then average_assists = '75pct';
	else if avg_assists le 199.091 and avg_assists gt 104.273 then average_assists = '90pct';
	else if avg_assists le 264.667 and avg_assists gt 199.091 then average_assists = '95pct';
	else if avg_assists gt 264.667 then average_assists = 'greater than 95 pct';
	
	/*

	Quantiles for points column
		95%	1041.455
		90%	817.231
		75% Q3	492.667	
		50% Median	222.688
		25% Q1	62.000
	*/
	
	if avg_points le 62.000 and avg_points ge 0 then average_points = '25pct';
	else if avg_points le 222.688 and avg_points gt 62.000 then average_points = 'median';
	else if avg_points le 492.667 and avg_points gt 222.688 then average_points = '75pct';
	else if avg_points le 817.231 and avg_points gt 492.667 then average_points = '90pct';
	else if avg_points le 1041.455 and avg_points gt 817.231 then average_points = '95pct';
	else if avg_points gt 1041.455 then average_points = 'greater than 95 pct';
		
	*average free throw percentage levels: 
	0 to 20th percentile: very low (0 - .6)
	21st to 40th percentile: low (.6 - .685)	
	41st to 60th percentile: medium (.685 - .7436)
	61st to 80th percentile: high	(.7436 - .79733)
	81st to 100 percentile: very high (.79733 - 1);
	
	if avg_freethrowpct lt 0.6 and avg_freethrowpct ge 0 then average_ft_pct = 'very low';
	else if avg_freethrowpct lt 0.685 and avg_freethrowpct ge 0.6 then average_ft_pct = 'low';
	else if avg_freethrowpct lt 0.7436 and avg_freethrowpct ge 0.685 then average_ft_pct = 'medium';
	else if avg_freethrowpct lt 0.79733 and avg_freethrowpct ge 0.7436 then average_ft_pct = 'high';
	else if avg_freethrowpct ge 0.79733 then average_ft_pct = 'very high';
	
	*starting age levels extremely subjective. didn't use traditional statistics to determine levels;
	if start_age=18 or start_age = 19 then starting_age = '18 or 19';
	else if start_age=20 then starting_age = '20 years';
	else if start_age=21 then starting_age = '21 years';
	else if start_age=22 then starting_age = '22 years';
	else if start_age gt 22 and start_age le 25 then starting_age = '23 to 25';
	else if start_age gt 25 then starting_age = 'greater than 25';
	
 	if team_count > 1 then multiple_teams = 'Yes';
 	else if team_count = 1 then multiple_teams = 'No';
	run;
	
	proc print data = player_career_length (obs = 50);
	
	PROC SGPLOT DATA = player_career_length;
	title "Swing Man Frequency";
	VBAR swing_man;
	RUN;
/* seasons, % assists, Swingman, Avg games, age, and points variables*/
data final_player_career_length;
	set player_career_length (drop = birth_date	birth_city birth_state year_start year_end position career_length
	bmi bmi_recode censor 	height_cm	weight_kg average_games	average_assists	average_points	starting_age
	college avg_shootingpercentage avg_freethrowrt avg_freethrowpct 
	team_count average_shootingpercentage average_ft_pct	multiple_teams);
	
proc print data = final_player_career_length (obs = 50);
   
**********************************************ANALYSIS************************************************
*summarys;  
**********************************************START AGE***********************************************; 
Proc sort data=player_final1;
   by start_age;   
   run;
proc summary data=player_final1;
   var start_age;
   output out=startagesum min=min max=max median=median;
run;
*********************************************CAREER LENGTH*******************************************;
Proc sort data=player_final1;
   by career_length;   
   run;
proc summary data=player_final1;
   var career_length;
   output out=Careerlengthsum min=min max=max median=median mean=mean;
run;

*scatter plot;
ODS GRAPHICS on/ ANTIALIASMAX=4600; *the data exceed the max number of graphical element;
title 'Scatter Plot for Start age by Career_length';
proc SGPLOT data = player_final1;
        scatter x= Start_age y = Career_length ;
        xaxis Label ='Start Age';
        yaxis label = 'Career Length';
run;



	


************************************************* BMI ************************************************;
Proc sort data=player_final1;
  by BMI;
  run;
proc summary data=player_final1;
   var BMI;
   output out=BMIsum min=min max=max median=median mean=mean;
run;   

*scatterplot for BMI;
title 'Scatter Plot for BMI by Career_length';
proc SGPLOT data = player_final1;
        scatter x= BMI y = Career_length ;
        xaxis Label ='BMI';
        yaxis label = 'Career Length';
run;

*******************college does not overlap frequently;
proc freq data=player_final1;
   table college;
   run;
   
************************************************* STATE *************************************************;
proc sort data=player_final1;
 by birth_state;
 run;
proc freq data=player_final1;
   table birth_state;
   run;

title 'Box Plot for career length by birth state';
   proc boxplot data=player_final1;
      plot career_length*birth_state /MAXPANELS=120;
        label birth_state ='Birth state';
        label career_length = 'career length';
   run;
   
************************************************* POSITION *************************************************;
proc sort data=player_final1;
 by position;
 run;
proc freq data=player_final1;
   table position;
   run;

title 'Box Plot for career length by position';
   proc boxplot data=player_final1;
      plot career_length*position /MAXPANELS=120;
        label position ='position';
        label career_length = 'career length';
   run;


	
PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_points;
RUN;

PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_games;
RUN;

PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_shootingpercentage;
RUN;

PROC UNIVARIATE DATA = player_season_count;
var avg_shootingpercentage;
output out=shootpct pctlpre=shootpctfifths pctlpts=20,40,60,80; 
run; 

proc print data = shootpct;
run;

PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_assists;
RUN;

PROC UNIVARIATE DATA = player_season_count;
HISTOGRAM avg_freethrowpct;
RUN;

PROC UNIVARIATE DATA = player_season_count;
var avg_freethrowpct;
output out=shootftpct pctlpre=shootftpctfifths pctlpts=20,40,60,80; 
run;

proc print data = shootftpct;
run;


	
proc lifetest data = combined3 method=km nelson plots=(s,h(BW=4));
	time seasons*Censor(0);
	run;
	
proc lifetest data = combined3 method = life nelson intervals = (1 to 33) 
plots = (survival, hazard(BW = 3, kernel = E));
	time seasons*Censor(0);
	run;
	
**********************************************************************************************;
**********************testing different covariates********************************************;
	
/*
covariates: 
seasons, games, points, position, bmi, start age, swing man, true shooting percentage,
free throw percentage, assists
*/

	
************************************************ SWING MAN *************************************************;
proc sort data=player_final1;
   by swing_man;
   run;
proc freq data=player_final1;
   table swing_man;
   run;

title 'Box Plot for career length by swing man';
   proc boxplot data=player_final1;
      plot career_length*swing_man /MAXPANELS=120;
        label swing_man ='swing man';
        label career_length = 'career length';
   run;

*********************************************** Seasons File ***********************************************;
*Points;
proc sort data=seasons_stats2;
   by points;
   run;

title 'Scatter Plot for points by season';
proc SGPLOT data = seasons_stats2;
        scatter x= season y = points ;
        xaxis Label ='season';
        yaxis label = 'points';
run;

proc print data = seasons_stats2 (obs = 200);
run;


***************************************************** AGE *****************************************************;
proc sort data=seasons_stats2;
   by AGE;
   run;
proc freq data=seasons_stats2;
   table Age;
   run;
title 'Box Plot for points by age';
   proc boxplot data=seasons_stats2;
      plot points*age /MAXPANELS=120;
        label age ='age';
        label points = 'points';
   run;
title 'Scatter Plot for points by AGE';
proc SGPLOT data = seasons_stats2;
        scatter x= Age y = points ;
        xaxis Label ='Age';
        yaxis label = 'points';
run;

************************************************** Position **************************************************;
proc sort data=seasons_stats2;
   by position;
   run;
proc freq data=seasons_stats2;
   table position;
   run;
title 'Box Plot for points by position';
   proc boxplot data=seasons_stats2;
      plot points*position /MAXPANELS=120;
        label position ='position';
        label points = 'points';
   run;
title 'Scatter Plot for points by position';
proc SGPLOT data = seasons_stats2;
        scatter x= position y = points ;
        xaxis Label ='position';
        yaxis label = 'points';
run;

**************************************************** TEAM ******************************************************;
proc sort data=seasons_stats2;
   by team;
   run;
proc freq data=seasons_stats2;
   table team;
   run;
title 'Box Plot for points by team';
   proc boxplot data=seasons_stats2;
      plot points*team /MAXPANELS=120;
        label team ='team';
        label points = 'points';
   run;
title 'Scatter Plot for points by team';
proc SGPLOT data = seasons_stats2;
        scatter x= team y = points ;
        xaxis Label ='team';
        yaxis label = 'points';
run;

**************************************************** GAMES ******************************************************;
proc sort data=seasons_stats2;
   by games;
   run;
proc freq data=seasons_stats2;
   table games;
   run;
title 'Box Plot for points by games';
   proc boxplot data=seasons_stats2;
      plot points*games /MAXPANELS=120;
        label games ='games';
        label points = 'points';
   run;
title 'Scatter Plot for points by games';
proc SGPLOT data = seasons_stats2;
        scatter x= games y = points ;
        xaxis Label ='games';
        yaxis label = 'points';
run;

**********************************************************************************************************;
*************************************bare bones model****************************************************;
*************************************credit: Sean*********************************************************;

	
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS,h,h(BW=6 kernel=E)) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
	
	
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS,h,h(BW=6 kernel=B)) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
	
	ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS,h,h(BW=6 kernel=U)) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
	
/*
proc lifetest data = combined3 method = life nelson intervals = (1 to 33) 
plots = (survival, hazard(BW = 3, kernel = E));
	time seasons*Censor(0);
	run;
*/	

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=life nelson intervals = (1 to 33) 
plots = (S, hazard(BW = 4, kernel = E), LS, LLS)
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

********************************************************************************************************;
*************************covariate analysis km curves***************************************************;
*************************credit: Sean*************************************************************************;

/*
covariates: 
seasons, games, points, position, bmi, start age, swing man, true shooting percentage,
free throw percentage, assists
*/

******************* kaplan-meier curves for games played ****************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_games/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_games/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for shooting percentage**********************;

	
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_shootingpercentage/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_shootingpercentage/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************** kaplan-meier curves for free throw percentage*******************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_ft_pct/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_ft_pct/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for assists**********************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_assists/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_assists/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for points*************************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_points/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_points/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;	

*******************kaplan-meier curves for position************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata position/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata position/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************kaplan-meier curves for bmi*********************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata bmi_recode/test=all adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata bmi_recode/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

*****************kaplan-meier curves for start age**************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata starting_age/test=all adjust=tukey ;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata starting_age/test=fleming(0,1) adjust=tukey ;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
****************kaplan-meier curves for swing man***************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata swing_man/test=all adjust=tukey ;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata swing_man/test=fleming(0,1) adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

***************** kaplan-meier curves for multiple teams*********************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata multiple_teams/test=all adjust=tukey ;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata multiple_teams/test=fleming(0,1) adjust=tukey ;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

************************************************trend******************************;
****************kaplan-meier curves for swing man***************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(S, LS, LLS) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata swing_man/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************kaplan-meier curves for bmi*********************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata bmi_recode/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


*****************kaplan-meier curves for start age**************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata starting_age/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for assists**********************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_assists/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for points*************************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_points/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


******************* kaplan-meier curves for shooting percentage**********************;

	
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_shootingpercentage/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


******************** kaplan-meier curves for free throw percentage*******************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_ft_pct/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for games played ****************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_games/trend;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
****************************kernel***********************************************;
******************* kaplan-meier curves for games played ****************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h(BW=4 kernel=E)) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_games/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for shooting percentage**********************;
	
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_shootingpercentage/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


******************** kaplan-meier curves for free throw percentage*******************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_ft_pct/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


******************* kaplan-meier curves for assists**********************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))   
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_assists/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

******************* kaplan-meier curves for points*************************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata average_points/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;
	


******************kaplan-meier curves for bmi*********************************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata bmi_recode/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


*****************kaplan-meier curves for start age**************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata starting_age/test=logrank adjust=tukey;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;

****************kaplan-meier curves for swing man***************************;

ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E)) 
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata swing_man;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


***************** kaplan-meier curves for multiple teams*********************;
ods output ProductLimitEstimates = ple;
PROC LIFETEST DATA = player_career_length METHOD=KM Nelson PLOTS=(h,h(BW=4 kernel=E))  
outsurv=out2 conftype= linear confband = all alpha=0.05;
TIME seasons*censor(0);
strata multiple_teams;
TITLE1 FONT="Arial 10pt" HEIGHT=1 BOLD 'Kaplan-Meier Curve --overall';
RUN;


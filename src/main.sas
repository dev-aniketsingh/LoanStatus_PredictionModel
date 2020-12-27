/* Term project-STAT 5811
Aniket Singh
Subha Raut
Subham Singh
*/
/* Importing the datafile */
proc import datafile="~/termpaper/newLoanData.xlsx" out=project dbms=xlsx 
		replace;
run;

libname loandata "~/termpaper";

/* Splitting data for avoiding optimism bias : Honest Assessment */
proc sort data=project out=work.project_sort;
	by loan_status;
run;

proc surveyselect noprint data=project_sort samprate=.6667 stratumseed=restore 
		out=project_sample seed=44444 outall;
	strata loan_status;
run;

/* Verify Stratification */
proc freq data=project_sample;
	tables loan_status*selected;
run;

data train(drop=selected SelectionProb SamplingWeight) validate(drop=selected 
		SelectionProb SamplingWeight);
	set project_sample;

	if selected then
		output train;
	else
		output validate;
run;

/* Impute missing values with medians */
proc stdize data=train reponly method=median out=train_imputed;
	var mths_since_last_delinq mths_since_last_record last_pymnt_d 
		debt_settlement_flag_date settlement_date settlement_amount 
		settlement_percentage settlement_term revol_util;
run;

/* Introducing new categories in place of missing values in character variables and
dropping the columns with only one labels or many levels */
data train_imputed_new;
	set train_imputed;
	drop zip_code sub_grade desc title pymnt_plan emp_title initial_list_status 
		hardship_flag disbursement_method application_type;
run;

data WORK.TRAIN_IMPUTED_NEW;
	length settlement_status $ 8;
	set WORK.TRAIN_IMPUTED_NEW;

	select (settlement_status);
		when (' ') settlement_status='other';
		otherwise settlement_status=settlement_status;
	end;
run;

data WORK.TRAIN_IMPUTED_NEW;
	length emp_length $ 64;
	set WORK.TRAIN_IMPUTED_NEW;

	select (emp_length);
		when (' ') emp_length='other';
		otherwise emp_length=emp_length;
	end;
run;

data train_imputed_new;
	set train_imputed_new;
	loan_status_new=0;

	if loan_status="Fully Paid" then
		loan_status_new=1;
run;

proc means data=work.train_imputed_new noprint nway;
	class purpose;
	var loan_status_new;
	output out=level mean=prop;
run;

proc print data=level;
run;

ods output clusterhistory=cluster;

proc cluster data=level method=ward outtree=fortree plots=(dendrogram(vertical 
		height=rsq));
	freq _freq_;
	var prop;
	id purpose;
run;

proc freq data=train_imputed_new noprint;
	tables purpose*loan_status_new / chisq;
	output out=work.chi(keep=_pchi_) chisq;
run;

data cutoff;
	if _n_=1 then
		set chi;
	set cluster;
	chisquare=_pchi_*rsquared;
	degfree=numberofclusters-1;
	logpvalue=logsdf('CHISQ', chisquare, degfree);
run;

title1 "Plot of the log of the p-value of number of clusters";

proc sgplot data=cutoff;
	scatter y=logpvalue x=numberofclusters / markerattrs=(color=blue 
		symbol=circlefilled);
	xaxis label="Number of clusters";
	yaxis label="Log of p-value";
run;

title1;

proc sql;
	select NumberOfClusters into: ncl from cutoff having logpvalue=min(logpvalue);
quit;

proc tree data=fortree nclusters=&ncl out=clus noprint;
	id purpose;
run;

proc sort data=clus;
	by clusname;
run;

title1 "Levels of purpose by cluster";

proc print data=clus;
	by clusname;
	id clusname;
run;

title1;
filename brclus "~/termpaper/purpose.sas";

data _null_;
	file brclus;
	set clus end=last;

	if _n_=1 then
		put "select(purpose);";
	put " when('" purpose +(-1) "') purpose='" cluster +(-1) "';";

	if last then
		do;
			put " otherwise purpose_clus = 'U';"/ "end;";
		end;
run;

data train_imputed_greenacre;
	set train_imputed_new;
	%include brclus/source2;
run;

proc means data=work.train_imputed_new noprint nway;
	class addr_state;
	var loan_status_new;
	output out=level mean=prop;
run;

proc print data=level;
run;

ods output clusterhistory=cluster;

proc cluster data=level method=ward outtree=fortree plots=(dendrogram(vertical 
		height=rsq));
	freq _freq_;
	var prop;
	id addr_state;
run;

proc freq data=train_imputed_new noprint;
	tables addr_state*loan_status_new / chisq;
	output out=work.chi(keep=_pchi_) chisq;
run;

data cutoff;
	if _n_=1 then
		set chi;
	set cluster;
	chisquare=_pchi_*rsquared;
	degfree=numberofclusters-1;
	logpvalue=logsdf('CHISQ', chisquare, degfree);
run;

title1 "Plot of the log of the p-value of number of clusters";

proc sgplot data=cutoff;
	scatter y=logpvalue x=numberofclusters / markerattrs=(color=blue 
		symbol=circlefilled);
	xaxis label="Number of clusters";
	yaxis label="Log of p-value";
run;

title1;

proc sql;
	select NumberOfClusters into: ncl from cutoff having logpvalue=min(logpvalue);
quit;

proc tree data=fortree nclusters=&ncl out=clus noprint;
	id addr_state;
run;

proc sort data=clus;
	by clusname;
run;

title1 "Levels of addr_state by cluster";

proc print data=clus;
	by clusname;
	id clusname;
run;

title1;
filename brclus "~/termpaper/addr_state.sas";

data _null_;
	file brclus;
	set clus end=last;

	if _n_=1 then
		put "select(addr_state);";
	put " when('" addr_state +(-1) "') addr_state='" cluster +(-1) "';";

	if last then
		do;
			put " otherwise addr_state_clus = 'U';"/ "end;";
		end;
run;

data train_imputed_greenacre;
	set train_imputed_new;
	%include brclus/source2;
run;

data WORK.TRAIN_IMPUTED_NEW;
	length addr_state $ 4;
	set WORK.TRAIN_IMPUTED_NEW;

	select(addr_state);
		when ('CA') addr_state='3';
		when ('MT') addr_state='3';
		when ('GA') addr_state='3';
		when ('RI') addr_state='3';
		when ('OH') addr_state='3';
		when ('CT') addr_state='3';
		when ('KY') addr_state='3';
		when ('NV') addr_state='5';
		when ('SD') addr_state='5';
		when ('AK') addr_state='5';
		when ('MN') addr_state='1';
		when ('NH') addr_state='1';
		when ('MS') addr_state='1';
		when ('TN') addr_state='1';
		when ('UT') addr_state='1';
		when ('WV') addr_state='1';
		when ('LA') addr_state='1';
		when ('WI') addr_state='1';
		when ('CO') addr_state='1';
		when ('DE') addr_state='1';
		when ('VT') addr_state='1';
		when ('DC') addr_state='1';
		when ('KS') addr_state='1';
		when ('SC') addr_state='1';
		when ('WY') addr_state='1';
		when ('AR') addr_state='1';
		when ('AZ') addr_state='1';
		when ('TX') addr_state='1';
		when ('FL') addr_state='4';
		when ('HI') addr_state='4';
		when ('MD') addr_state='4';
		when ('VA') addr_state='4';
		when ('OR') addr_state='4';
		when ('MI') addr_state='4';
		when ('NM') addr_state='4';
		when ('AL') addr_state='2';
		when ('NY') addr_state='2';
		when ('IL') addr_state='2';
		when ('WA') addr_state='2';
		when ('NC') addr_state='2';
		when ('PA') addr_state='2';
		when ('OK') addr_state='2';
		when ('NJ') addr_state='2';
		when ('MA') addr_state='2';
		when ('MO') addr_state='2';
		otherwise addr_state_clus='U';
	end;
run;

data WORK.TRAIN_IMPUTED_NEW;
	length purpose $ 25;
	set WORK.TRAIN_IMPUTED_NEW;

	select(purpose);
		when ('car') purpose='1';
		when ('wedding') purpose='1';
		when ('credit_card') purpose='1';
		when ('home_improvement') purpose='1';
		when ('major_purchase') purpose='1';
		when ('house') purpose='1';
		when ('renewable_energy') purpose='1';
		when ('medical') purpose='2';
		when ('vacation') purpose='2';
		when ('debt_consolidation') purpose='2';
		when ('other') purpose='2';
		when ('moving') purpose='2';
		when ('small_business') purpose='3';
		otherwise purpose_clus='U';
	end;
run;

data train_imputed_new;
	length grade $ 1;
	set WORK.TRAIN_IMPUTED_NEW;

	select (grade);
		when ('A') grade='1';
		when ('B') grade='2';
		when ('C') grade='3';
		when ('D') grade='4';
		when ('E') grade='5';
		when ('F') grade='5';
		when ('G') grade='5';
		otherwise grade=grade;
	end;
run;

/* Reducing redundancy by clustering variables */
ods select none;
ods output clusterquality=summary rsquare=clusters;

proc varclus data=train_imputed_new maxeigen=.8 hi;
	var loan_amnt funded_amnt funded_amnt_inv int_rate installment annual_inc dti 
		delinq_2yrs inq_last_6mths mths_since_last_delinq mths_since_last_record 
		open_acc pub_rec revol_bal revol_util total_acc total_pymnt total_pymnt_inv 
		total_rec_prncp total_rec_int total_rec_late_fee recoveries 
		collection_recovery_fee last_pymnt_amnt pub_rec_bankruptcies 
		settlement_amount settlement_percentage settlement_term;
run;

ods select all;
%global nvar;

data _null_;
	set summary;
	call symput('nvar', compress(NumberOfClusters));
run;

title1 "Variables by Cluster";

proc print data=clusters noobs label split='*';
	where NumberOfClusters=&nvar;
	var Cluster Variable RSquareRatio VariableLabel;
	label RSquareRatio="1-Rsquare*Ratio";
run;

title1;
title1 "Variation Explained By Clusters";

proc print data=summary label;
run;

%global reduced;
%let reduced= loan_amnt settlement_amount recoveries pub_rec open_acc delinq_2yrs revol_util settlement_term int_rate mths_since_last_record inq_last_6mths total_rec_late_fee annual_inc settlement_percentage last_pymnt_amnt;

/* Performing variable screening */
ods select none;
ods output spearmancorr=spearman hoeffdingcorr=hoeffding;

proc corr data=train_imputed_new spearman hoeffding;
	var loan_status_new;
	with &reduced;
run;

ods select all;

proc sort data=spearman;
	by variable;
run;

proc sort data=hoeffding;
	by variable;
run;

data correlations;
	merge spearman(rename=(loan_status_new=scorr ploan_status_new=spvalue)) 
		hoeffding(rename=(loan_status_new=hcorr ploan_status_new=hpvalue));
	by variable;
	score_abs=abs(scorr);
	hcorr_abs=abs(hcorr);
run;

proc rank data=correlations out=correlations1 descending;
	var score_abs hcorr_abs;
	ranks ranksp rankho;
run;

proc sort data=correlations1;
	by ranksp;
run;

title1 "Rank of Spearman Correlations and Heoffding Correlations";

proc print data=correlations1 label split='*';
	var variable ranksp rankho scorr spvalue hcorr hpvalue;
	label ranksp='Spearman rank of variables' rankho='Hoeffding rank of variables' 
		scorr='Spearman correlation' spvalue='Spearman value' 
		hcorr='Hoeffding correlation' hpvalue='Hoeffding p-value';
run;

title1;
%global vref href;

proc sql noprint;
	select min(ranksp) into: vref from(select ranksp from correlations1 having 
		spvalue>.5);
	select min(rankho) into: href from(select rankho from correlations1 having 
		hpvalue>.5);
quit;

title1 "Scatterplot of the ranks of Spearman vs Hoeffding";

proc sgplot data=correlations1;
	refline &vref /axis=y;
	refline &href /axis=x;
	scatter y=ranksp x=rankho / datalabel=variable;
	yaxis label="Rank of Spearman";
	xaxis label="Rank of Hoeffding";
run;

title1;
%global screened;
%let screened=loan_amnt recoveries pub_rec open_acc delinq_2yrs revol_util settlement_term int_rate mths_since_last_record inq_last_6mths total_rec_late_fee annual_inc last_pymnt_amnt;

data train_imputed_new;
	set train_imputed_new;
	drop settlement_status;
run;

data train_imputed_new;
	set train_imputed_new;

	if home_ownership="OTHER" then
		home_ownership="RENT";
run;

%global categorical_inputs;
%let categorical_inputs= grade emp_length purpose addr_state term home_ownership verification_status;

data validate;
	length purpose $ 25;
	set validate;

	select(purpose);
		when ('car') purpose='1';
		when ('wedding') purpose='1';
		when ('credit_card') purpose='1';
		when ('home_improvement') purpose='1';
		when ('major_purchase') purpose='1';
		when ('house') purpose='1';
		when ('renewable_energy') purpose='1';
		when ('medical') purpose='2';
		when ('vacation') purpose='2';
		when ('debt_consolidation') purpose='2';
		when ('other') purpose='2';
		when ('moving') purpose='2';
		when ('small_business') purpose='3';
		otherwise purpose_clus='U';
	end;
run;

data validate;
	length addr_state $ 4;
	set validate;

	select(addr_state);
		when ('CA') addr_state='3';
		when ('MT') addr_state='3';
		when ('GA') addr_state='3';
		when ('RI') addr_state='3';
		when ('OH') addr_state='3';
		when ('CT') addr_state='3';
		when ('KY') addr_state='3';
		when ('NV') addr_state='5';
		when ('SD') addr_state='5';
		when ('AK') addr_state='5';
		when ('MN') addr_state='1';
		when ('NH') addr_state='1';
		when ('MS') addr_state='1';
		when ('TN') addr_state='1';
		when ('UT') addr_state='1';
		when ('WV') addr_state='1';
		when ('LA') addr_state='1';
		when ('WI') addr_state='1';
		when ('CO') addr_state='1';
		when ('DE') addr_state='1';
		when ('VT') addr_state='1';
		when ('DC') addr_state='1';
		when ('KS') addr_state='1';
		when ('SC') addr_state='1';
		when ('WY') addr_state='1';
		when ('AR') addr_state='1';
		when ('AZ') addr_state='1';
		when ('TX') addr_state='1';
		when ('FL') addr_state='4';
		when ('HI') addr_state='4';
		when ('MD') addr_state='4';
		when ('VA') addr_state='4';
		when ('OR') addr_state='4';
		when ('MI') addr_state='4';
		when ('NM') addr_state='4';
		when ('AL') addr_state='2';
		when ('NY') addr_state='2';
		when ('IL') addr_state='2';
		when ('WA') addr_state='2';
		when ('NC') addr_state='2';
		when ('PA') addr_state='2';
		when ('OK') addr_state='2';
		when ('NJ') addr_state='2';
		when ('MA') addr_state='2';
		when ('MO') addr_state='2';
		otherwise addr_state_clus='U';
	end;
run;

%global sl;

proc sql;
	select 1-probchi(log(sum(loan_status_new ge 0)), 1) into: sl from 
		train_imputed_new;
quit;

proc logistic data=train_imputed_new
			  plots(maxpoints=none);
	class &categorical_inputs/ param=ref;
	model loan_status(event="Fully Paid")=loan_amnt pub_rec open_acc delinq_2yrs 
		revol_util settlement_term int_rate mths_since_last_record inq_last_6mths 
		total_rec_late_fee annual_inc last_pymnt_amnt &categorical_inputs 
		/selection=backward fast slstay=&sl lackfit ctable clodds=pl pprob=0.70;
	output out=test p=ppred;
	units loan_amnt=1000 annual_inc=1000 /default=1;
	score data=validate out=logit_File fitstat outroc=vroc;
run;

proc npar1way edf data=logit_File;
	class loan_status;
	var 'P_Fully Paid'n;
run;

proc sql;
	select case_no, 'P_Fully Paid'n
	from logit_File
	where case_no=20000;
quit;


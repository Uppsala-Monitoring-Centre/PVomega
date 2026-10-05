/*****************************************
         Compute Omega values
*****************************************/
-- First, we construct several temporary tables to associate report IDs to either Drugs or Reactions
-- The first table with the reports and substances
-- The second table with the reports and reactions
-- Then, we use the temporary tables mentionned above to count numbers of reports
-- for single drugs
-- for single reactions
-- for drug-drug pairs
-- for drug-reaction pairs
-- Then, we create a table with all necessary counts to compute Omega and Omega025
-- Finally, we create the result table with the Omega values


use [UMCReport20181227]


---------------------------------------------------------
-- Drug table
---------------------------------------------------------
IF OBJECT_ID('tempdb..#ReportDrugList') IS NULL --NOT NULL
	--DROP TABLE #ReportDrugList
	BEGIN
	CREATE TABLE #ReportDrugList (
		ReportID INT, 
		Drecno char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		PRIMARY KEY (ReportID,Drecno))
	INSERT INTO #ReportDrugList
	SELECT DISTINCT Report.ReportID, 
	                Product.Drecno
	FROM UMCReport.Report			Report
	INNER JOIN [UMCReport].[Drug]	Drug	ON Drug.ReportID = Report.ReportID
	INNER JOIN [WHODrug].[Product]	Product ON Drug.UMCValidated_ProductID = Product.ProductID
	WHERE 1=1  
	  and (UMCCalculated_PreferredICSR_ReportID is null or UMCCalculated_PreferredICSR_ReportID=REPORT.ReportID) -- exclude suspected duplicates
	  and UMCCalculated_ForeignCase = 0 -- exclude foreign cases
      and Drug.UMCValidated_DrugCharacterizationID in (1,3) -- 1=Suspected, 2=Concomitant, 3=Interacting
END
-- Takes ~2 min to create
-- 22,819,875 rows

SELECT COUNT(*) FROM #ReportDrugList
SELECT TOP(100) * FROM #ReportDrugList


---------------------------------------------------------
-- Reaction table
---------------------------------------------------------
IF OBJECT_ID('tempdb..#ReportReactionList') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #ReportReactionList
	CREATE TABLE #ReportReactionList (
		ReportID INT
	  , MedDRAPTCode INT 
	  --, MedDRASOCCode INT
	  , PRIMARY KEY (ReportID,MedDRAPTCode/*, MedDRASOCCode*/))
	INSERT INTO #ReportReactionList
	SELECT DISTINCT Report.ReportID
	               ,Reaction.UMCValidated_ReactionMeddraPtCode AS MedDRAPTCode
				   --, Meddra.SOC_CODE AS MedDRASOCCode
	FROM UMCReport.Report		Report
	INNER JOIN [UMCReport].[Reaction]					Reaction	ON Reaction.ReportID = Report.ReportID
	--INNER JOIN [MedDRA].[MedDRA].[MEDDRA_MD_HIERARCHY]	Meddra		ON Reaction.UMCValidated_ReactionMeddraPtCode = Meddra.PT_CODE 
	WHERE 1=1  
	  and (UMCCalculated_PreferredICSR_ReportID is null or UMCCalculated_PreferredICSR_ReportID=REPORT.ReportID) -- exclude suspected duplicates
	  and UMCCalculated_ForeignCase = 0 -- exclude foreign cases
	  and Reaction.UMCValidated_ReactionMeddraPtCode is not null
	  --and Meddra.PRIMARY_SOC_FG='Y' -- to only include primary soc
END
-- takes 0.5 minutes to create 
-- 43,252,220 rows
	
SELECT COUNT(*) FROM #ReportReactionList
SELECT TOP(100) * FROM #ReportReactionList
	

---------------------------------------------------------
-- Single drug counts
---------------------------------------------------------
IF OBJECT_ID('tempdb..#SingleDrugCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #SingleDrugCounts 
	CREATE TABLE #SingleDrugCounts (
		Drecno char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		DrugName varchar(1500), 
		NbReports INT, 
		PRIMARY KEY (Drecno))
	INSERT INTO #SingleDrugCounts
	SELECT #ReportDrugList.Drecno
	     , NULL
		 , COUNT(DISTINCT #ReportDrugList.ReportID)
	FROM #ReportDrugList 
	GROUP BY #ReportDrugList.Drecno

	UPDATE #SingleDrugCounts
	SET DrugName = Product.[Name]
	FROM [WHODrug].[Product] Product 
	INNER JOIN #SingleDrugCounts ON #SingleDrugCounts.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS = Product.Drecno
	WHERE 1=1
	  and Product.SEQ1 = '01'  -- no salts
	  and Product.SEQ2 = '001' -- primary name variant
END
-- takes 3 seconds to create 
-- 20,024 rows
	
SELECT COUNT(*) FROM #SingleDrugCounts
SELECT TOP(100) * FROM #SingleDrugCounts
SELECT TOP(100) * FROM #SingleDrugCounts ORDER BY NbReports desc


---------------------------------------------------------
-- ADR counts
---------------------------------------------------------
IF OBJECT_ID('tempdb..#ReactionCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #ReactionCounts
	CREATE TABLE #ReactionCounts (
		MedDRAPTCode INT
	  , ReactionName varchar(100)
	  --, MedDRASOCCode INT
	  --, ReactionNameSOC varchar(100)
	  , NbReports INT
	  , PRIMARY KEY (MedDRAPTCode/*, MedDRASOCCode*/))
	INSERT INTO #ReactionCounts
	SELECT #ReportReactionList.MedDRAPTCode
	     , NULL
		 --, #ReportReactionList.MedDRASOCCode
		 --, NULL
		 , COUNT(DISTINCT #ReportReactionList.ReportID)
	FROM #ReportReactionList 
	GROUP BY #ReportReactionList.MedDRAPTCode--, #ReportReactionList.MedDRASOCCode

	UPDATE #ReactionCounts
	SET ReactionName = Meddra.PT_NAME
      --, ReactionNameSOC = Meddra.SOC_NAME
	FROM [MedDRA].[MedDRA].[MEDDRA_MD_HIERARCHY] AS Meddra	
	INNER JOIN #ReactionCounts ON #ReactionCounts.MedDRAPTCode = Meddra.PT_CODE --and #ReactionCounts.MedDRASOCCode = MedDRA.[SOC_CODE]
	WHERE 1=1
	  and Meddra.PRIMARY_SOC_FG = 'Y'
END
-- takes 2 seconds to create 
-- 19,710 rows

SELECT COUNT(*) FROM #ReactionCounts
SELECT TOP(100) * FROM #ReactionCounts
SELECT TOP(100) * FROM #ReactionCounts ORDER BY NbReports desc


---------------------------------------------------------
-- Drug-Drug counts
---------------------------------------------------------
IF OBJECT_ID('tempdb..#DrugDrugCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #DrugDrugCounts
	CREATE TABLE #DrugDrugCounts (
		DrecnoD1 char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		DrecnoD2 char(6) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		NbReports INT, 
		PRIMARY KEY (DrecnoD1,DrecnoD2)
	)
	INSERT INTO #DrugDrugCounts
	SELECT D1.Drecno, D2.Drecno, COUNT(DISTINCT D1.ReportID)
	FROM #ReportDrugList D1
	JOIN #ReportDrugList D2 ON D2.ReportID=D1.ReportID
	WHERE D1.Drecno != D2.Drecno
	GROUP BY D1.Drecno, D2.Drecno
END
-- takes 12 seconds to create 
-- 1,120,188 rows

SELECT COUNT(*) FROM #DrugDrugCounts
SELECT TOP(100) * FROM #DrugDrugCounts
SELECT TOP(100) D.* , P1.[Name], P2.[Name] 
       FROM #DrugDrugCounts AS D
       JOIN [WHODrug].[Product] P1 ON D.DrecnoD1 = P1.Drecno
       JOIN [WHODrug].[Product] P2 ON D.DrecnoD2 = P2.Drecno
	   WHERE P1.Seq1 = '01' and P1.Seq2 = '001' and P2.Seq1 = '01' and P2.Seq2 = '001'
	   ORDER BY NbReports desc

	   
---------------------------------------------------------
-- Drug-ADR counts
---------------------------------------------------------
IF OBJECT_ID('tempdb..#DrugReactionCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #DrugReactionCounts
	CREATE TABLE #DrugReactionCounts (
		Drecno char(6) COLLATE SQL_Latin1_General_CP1_CI_AS 
	  , MedDRAPTCode INT
	  , NbReports INT
      , PRIMARY KEY (Drecno,MedDRAPTCode)
	)
	INSERT INTO #DrugReactionCounts
	SELECT D.Drecno
	     , R.MedDRAPTCode, COUNT(DISTINCT D.ReportID)
	FROM #ReportDrugList D
	JOIN #ReportReactionList R ON R.ReportID=D.ReportID
	GROUP BY D.Drecno, R.MedDRAPTCode
END
-- takes 33 seconds to create 
-- 3,083,067 rows

SELECT COUNT(*) FROM #DrugReactionCounts
SELECT TOP(100) * FROM #DrugReactionCounts
SELECT TOP(100) DR.*, P.[Name], M.PT_NAME
	   FROM #DrugReactionCounts AS DR
	   JOIN [WHODrug].[Product] P ON DR.Drecno = P.Drecno
	   JOIN [MedDRA].[MedDRA].[MEDDRA_MD_HIERARCHY] M ON DR.MedDRAPTCode = M.PT_CODE
	   WHERE P.Seq1 = '01' and P.Seq2 = '001' and M.PRIMARY_SOC_FG = 'Y'
	   ORDER BY NbReports desc


---------------------------------------------------------
-- Big count table
---------------------------------------------------------


IF OBJECT_ID('tempdb..#Drug1And2AllCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #Drug1And2AllCounts
	
	DECLARE @n___ INT = (
		SELECT COUNT(DISTINCT Report.ReportID)
		FROM UMCReport.Report Report
		WHERE 1=1  
		  and (UMCCalculated_PreferredICSR_ReportID is null or UMCCalculated_PreferredICSR_ReportID=REPORT.ReportID) -- exclude suspected duplicates
		  and UMCCalculated_ForeignCase = 0 -- exclude foreign cases
	) 
	DECLARE @Drug1Drecno char(6) = (
		SELECT DISTINCT Product.Drecno
		FROM [WHODrug].[Product] AS Product
		WHERE Product.[Name] = 'ipilimumab'
	)
	DECLARE @Drug2Drecno char(6) = (
		SELECT DISTINCT Product.Drecno
		FROM [WHODrug].[Product] AS Product
		WHERE Product.[Name] = 'nivolumab'
	)

	CREATE TABLE #Drug1And2AllCounts (
		Drecno1 varchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Drug1 varchar(1500) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		Drecno2 varchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Drug2 varchar(1500) COLLATE SQL_Latin1_General_CP1_CI_AS,
		--MedDRASOC INT ,
		MedDRAPT INT,
		--SOC varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Reaction varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		n___ INT,
		n1__ INT,
		n_1_ INT,
		n__1 INT,
		n11_ INT,
		n1_1 INT,
		n_11 INT,
		Observed INT,
		Expected INT,
		PRIMARY KEY (Drecno1,Drecno2,MedDRAPT/*, MedDRASOC*/)
	)
	INSERT INTO #Drug1And2AllCounts 
	SELECT 
		D1.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS AS Drecno1, 
		SingleD1.DrugName COLLATE SQL_Latin1_General_CP1_CI_AS AS Drug1,
		D2.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS AS Drecno2, 
		SingleD2.DrugName COLLATE SQL_Latin1_General_CP1_CI_AS AS Drug2,
		--ADR.MedDRASOCCode ,
		ADR.MedDRAPTCode AS MedDRAPT, 
		--SingleR.ReactionNameSOC ,
		SingleR.ReactionName AS Reaction,
		@n___ AS n___,
		SingleD1.NbReports AS n1__, 
		SingleD2.NbReports AS n_1_,
		SingleR.NbReports AS n__1,
		DD.NbReports AS n11_,
		RD1.NbReports AS n1_1,
		RD2.NbReports AS n_11,
		COUNT(DISTINCT D1.ReportID) AS Observed,
		ResearchProjects.dbo.CxxyExpected(@n___, SingleD1.NbReports, SingleD2.NbReports, SingleR.NbReports, DD.NbReports, RD1.NbReports, RD2.NbReports, COUNT(DISTINCT D1.ReportID)) AS Expected
	FROM #ReportDrugList		D1
	JOIN #ReportDrugList		D2			ON D2.ReportID = D1.ReportID
	JOIN #ReportReactionList	ADR			ON ADR.ReportID = D1.ReportID
	JOIN #SingleDrugCounts		SingleD1	ON SingleD1.Drecno = D1.Drecno
	JOIN #SingleDrugCounts		SingleD2	ON SingleD2.Drecno = D2.Drecno
	JOIN #ReactionCounts		SingleR		ON SingleR.MedDRAPTCode = ADR.MedDRAPTCode  --and SingleR.MedDRASOCCode = ADR.MedDRASOCCode
	JOIN #DrugDrugCounts		DD			ON DD.DrecnoD1 = D1.Drecno	AND DD.DrecnoD2 = D2.Drecno
	JOIN #DrugReactionCounts	RD1			ON RD1.Drecno = D1.Drecno	AND RD1.MedDRAPTCode = ADR.MedDRAPTCode
	JOIN #DrugReactionCounts	RD2			ON RD2.Drecno = D2.Drecno	AND RD2.MedDRAPTCode = ADR.MedDRAPTCode
	--LEFT JOIN UMCReport.ReferenceTermSMQ.SMQ_LIST li ON ADR.MedDRAPTCode = li.
	WHERE 1=1
	  and D1.Drecno = @Drug1Drecno
	  and D2.Drecno = @Drug2Drecno
	  and D1.Drecno != D2.Drecno

	GROUP BY 
		D1.Drecno, 
		SingleD1.DrugName,
		D2.Drecno, 
		SingleD2.DrugName,
		--ADR.MedDRASOCCode,
		ADR.MedDRAPTCode, 
		--SingleR.ReactionNameSOC,
		SingleR.ReactionName,
		SingleD1.NbReports, 
		SingleD2.NbReports,
		SingleR.NbReports,
		DD.NbReports,
		RD1.NbReports,
		RD2.NbReports
	ORDER BY Observed DESC
END
-- takes 1 seconds to create 
-- 1,402 rows

SELECT COUNT(*) FROM #Drug1And2AllCounts
SELECT TOP(100) * FROM #Drug1And2AllCounts
SELECT * FROM #Drug1And2AllCounts


-------------------------------------------------------
-- Create result file 
-------------------------------------------------------

SELECT DISTINCT
	Result.Drug1,
	Result.Drug2,
	--Result.SOC,
	Result.Reaction,
	Result.Observed as NbObserved,
	Result.Expected as NbExpected, 
	ResearchProjects.dbo.ICoe(Result.Observed, Result.Expected) AS Omega, 
	ResearchProjects.dbo.ICoe025(Result.Observed, Result.Expected) AS Omega025,
	Result.n___ as NbVigiBase,
	Result.n1__ as NbDrug1,
	Result.n_1_ as NbDrug2,
	Result.n__1 as NbReaction,
	Result.n11_ as NbDrug1Drug2,
	Result.n1_1 as NbDrug1Reaction,
	Result.n_11 as NbDrug2Reaction
FROM #Drug1And2AllCounts Result
WHERE 1=1
  --and ResearchProjects.dbo.ICoe025(Result.Observed, Result.Expected) > 0 -- restriction: only when Omega025 > 0 included in result								
ORDER BY Omega025 DESC
-- takes 0 seconds to create 
-- 1,402 rows



DROP TABLE #ReportDrugList
DROP TABLE #ReportReactionList
DROP TABLE #SingleDrugCounts 
DROP TABLE #ReactionCounts 
DROP TABLE #DrugDrugCounts
DROP TABLE #DrugReactionCounts
DROP TABLE #Drug1And2AllCounts


/*-------------------------------------------------------
-- We add the SMQs
-------------------------------------------------------

IF OBJECT_ID('tempdb..#Drug1AllCountsSMQ') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #Drug1AllCountsSMQ
	CREATE TABLE #Drug1AllCountsSMQ (
		Drecno1 varchar(6),
		Drug1 varchar(1500), 
		Drecno2 varchar(6),
		Drug2 varchar(1500),
		MedDRASOC INT,
		MedDRAPT INT,
		SOC varchar(100),
		Reaction varchar(100), 
		SMQCode INT,
		SMQName varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		SMQScope varchar(255) COLLATE SQL_Latin1_General_CP1_CI_AS,
		n___ INT,
		n1__ INT,
		n_1_ INT,
		n__1 INT,
		n11_ INT,
		n1_1 INT,
		n_11 INT,
		Observed INT,
		Expected INT,
		PRIMARY KEY (Drecno1,Drecno2,MedDRAPT,MedDRASOC,SMQCode,SMQScope)
	)
	INSERT INTO #Drug1AllCountsSMQ 
	SELECT 
		DAC.Drecno1, 
		DAC.Drug1,
		DAC.Drecno2, 
		DAC.Drug2,
		DAC.MedDRASOC ,
		DAC.MedDRAPT , 
		DAC.SOC ,
		DAC.Reaction ,
		COALESCE(SMQMap.SMQ_CODE,-1),
		COALESCE(SMQName.SMQ_NAME,'-'),
		COALESCE(SC.Description,'-'),
		DAC.n___,
		DAC.n1__, 
		DAC.n_1_,
		DAC.n__1,
		DAC.n11_,
		DAC.n1_1,
		DAC.n_11,
		DAC.Observed,
		DAC.Expected
	FROM #Drug1AllCounts											DAC
	LEFT JOIN ReferenceTermSMQ.SMQ_CONTENT		SMQMap			ON SMQMap.TERM_CODE = DAC.MedDRAPT AND SMQMap.TERM_STATUS = 'A'
	LEFT JOIN ReferenceTermSMQ.SMQ_LIST			SMQName			ON SMQName.SMQ_CODE = SMQMap.SMQ_CODE
	LEFT JOIN Lexicon.SMQScope					SC				ON SC.SMQScopeID = SMQMap.TERM_SCOPE

	GROUP BY 
		DAC.Drecno1, 
		DAC.Drug1,
		DAC.Drecno2, 
		DAC.Drug2,
		DAC.MedDRASOC,
		DAC.MedDRAPT, 
		DAC.SOC,
		DAC.Reaction,
		SMQMap.SMQ_CODE,
		SMQName.SMQ_NAME,
		SC.Description,
		DAC.n___,
		DAC.n1__, 
		DAC.n_1_,
		DAC.n__1,
		DAC.n11_,
		DAC.n1_1,
		DAC.n_11,
		DAC.Observed,
		DAC.Expected
	ORDER BY Observed DESC
	END

SELECT TOP(20) * FROM #Drug1AllCountsSMQ


SELECT DISTINCT
	AC.Drug1,
	AC.Drug2,
	AC.SOC,
	AC.Reaction,
	--CASE 
	--	WHEN AC.SMQName = 'Haemorrhage terms (excl laboratory terms) (SMQ)' THEN AC.SMQName 
	--	WHEN AC.SMQName = 'Haemorrhage laboratory terms (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Haemorrhagic central nervous system vascular conditions (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Conditions associated with central nervous system haemorrhages and cerebrovascular accidents (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Gastrointestinal perforation, ulcer, haemorrhage, obstruction non-specific findings/procedures (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Gastrointestinal haemorrhage (SMQ)' THEN AC.SMQName
	--	WHEN AC.SMQName = 'Liver-related coagulation and bleeding disturbances (SMQ)' THEN AC.SMQName
	--	ELSE '-' 
	--END AS SMQ,
	--CASE 
	--	WHEN AC.SMQName = 'Haemorrhage terms (excl laboratory terms) (SMQ)' THEN AC.SMQScope 
	--	WHEN AC.SMQName = 'Haemorrhage laboratory terms (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Haemorrhagic central nervous system vascular conditions (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Conditions associated with central nervous system haemorrhages and cerebrovascular accidents (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Gastrointestinal perforation, ulcer, haemorrhage, obstruction non-specific findings/procedures (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Gastrointestinal haemorrhage (SMQ)' THEN AC.SMQScope
	--	WHEN AC.SMQName = 'Liver-related coagulation and bleeding disturbances (SMQ)' THEN AC.SMQScope
	--	ELSE '-' 
	--END AS SMQScope,
	AC.Observed as NbObserved,
	AC.Expected as NbExpected, 
	ResearchProjects.dbo.ICoe(AC.Observed, AC.Expected) AS Omega, 
	ResearchProjects.dbo.ICoe025(AC.Observed, AC.Expected) AS Omega025,
	AC.n___ as NbVigiBase,
	AC.n1__ as NbDrug1,
	AC.n_1_ as NbDrug2,
	AC.n__1 as NbReaction,
	AC.n11_ as NbDrug1Drug2,
	AC.n1_1 as NbDrug1Reaction,
	AC.n_11 as NbDrug2Reaction
FROM #Drug1AllCountsSMQ AC
where ResearchProjects.dbo.ICoe025(AC.Observed, AC.Expected) > 0
		--AND AC.Reaction in (SELECT distinct MTI.MedDRAPTName COLLATE SQL_Latin1_General_CP1_CI_AS
		--									FROM UMCReport.Report							Report
		--									JOIN [UMCReport].[Reaction]					Reaction	ON Reaction.ReportID = Report.ReportID 
		--									JOIN [UMCReport].[TB_MappedTermInformation]	MTI			ON MTI.[MappedReportedTermID] = Reaction.[UMCValidated_MappedReportedTermID] 
		--									LEFT JOIN [UMCReport].[UMCCalculated_SMQ] ca ON report.ReportID = ca.ReportID 
		--									LEFT JOIN UMCReport.ReferenceTermSMQ.SMQ_LIST li ON ca.SMQ_CODE = li.SMQ_CODE 
		--									WHERE 
		--									Report.UMCCalculated_DeleteDate IS NULL AND Report.UMCCalculated_ForeignCase = 0
		--									AND (Report.UMCCalculated_PreferredICSR_ReportID IS NULL OR Report.UMCCalculated_PreferredICSR_ReportID = Report.ReportID)
		--									--AND li.[SMQ_code] in ('20000060', '20000038' ) 
		--									AND li.[SMQ_name] in ('haemorrhage laboratory terms (SMQ)', 'haemorrhage terms (excl laboratory terms) (SMQ)','Central nervous system haemorrhages and cerebrovascular conditions (SMQ)','Central nervous system vascular disorders (SMQ)' ) 
		--									AND ca.SMQscopeID = 2
		--								)
											
ORDER BY Omega025 DESC
*/

--DROP TABLE #Drug1AllCounts
--DROP TABLE #DrugReactionCounts
--DROP TABLE #DrugDrugCounts
--DROP TABLE #SingleDrugCounts 
--DROP TABLE #ReportDrugList
--DROP TABLE #ReportReactionList
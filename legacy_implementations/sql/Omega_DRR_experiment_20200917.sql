/*****************************************
         Compute Omega values
*****************************************/
-- First, we construct several temporary tables to associate report IDs to either Drugs or Reactions
-- The first table with the reports and substances
-- The second table with the reports and reactions
-- Then, we use the temporary tables mentionned above to count numbers of reports
-- for single drugs
-- for single reactions
-- for reaction-reaction pairs
-- for drug-reaction pairs
-- Then, we create a table with all necessary counts to compute Omega and Omega025
-- Finally, we create the result table with the Omega values


use [UMCReport20200830] --> [Meddra_20200830]


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
-- 28,144,486 rows

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
	--INNER JOIN [Meddra_20200830].[MedDRA].[MEDDRA_MD_HIERARCHY]	Meddra		ON Reaction.UMCValidated_ReactionMeddraPtCode = Meddra.PT_CODE 
	WHERE 1=1  
	  and (UMCCalculated_PreferredICSR_ReportID is null or UMCCalculated_PreferredICSR_ReportID=REPORT.ReportID) -- exclude suspected duplicates
	  and UMCCalculated_ForeignCase = 0 -- exclude foreign cases
	  and Reaction.UMCValidated_ReactionMeddraPtCode is not null
	  --and Meddra.PRIMARY_SOC_FG='Y' -- to only include primary soc
END
-- takes 1.5 minutes to create 
-- 53,186,737 rows
	
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
-- 21,306 rows
	
SELECT COUNT(*) FROM #SingleDrugCounts
SELECT TOP(100) * FROM #SingleDrugCounts
SELECT TOP(100) * FROM #SingleDrugCounts ORDER BY NbReports desc


---------------------------------------------------------
-- Single ADR counts
---------------------------------------------------------
IF OBJECT_ID('tempdb..#SingleReactionCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #SingleReactionCounts
	CREATE TABLE #SingleReactionCounts (
		MedDRAPTCode INT
	  , ReactionName varchar(100)
	  --, MedDRASOCCode INT
	  --, ReactionNameSOC varchar(100)
	  , NbReports INT
	  , PRIMARY KEY (MedDRAPTCode/*, MedDRASOCCode*/))
	INSERT INTO #SingleReactionCounts
	SELECT #ReportReactionList.MedDRAPTCode
	     , NULL
		 --, #ReportReactionList.MedDRASOCCode
		 --, NULL
		 , COUNT(DISTINCT #ReportReactionList.ReportID)
	FROM #ReportReactionList 
	GROUP BY #ReportReactionList.MedDRAPTCode--, #ReportReactionList.MedDRASOCCode

	UPDATE #SingleReactionCounts
	SET ReactionName = Meddra.PT_NAME
      --, ReactionNameSOC = Meddra.SOC_NAME
	FROM [Meddra_20200830].[MedDRA].[MEDDRA_MD_HIERARCHY] AS Meddra	
	INNER JOIN #SingleReactionCounts ON #SingleReactionCounts.MedDRAPTCode = Meddra.PT_CODE --and #ReactionCounts.MedDRASOCCode = MedDRA.[SOC_CODE]
	WHERE 1=1
	  and Meddra.PRIMARY_SOC_FG = 'Y'
END
-- takes 2 seconds to create 
-- 20,753 rows

SELECT COUNT(*) FROM #SingleReactionCounts
SELECT TOP(100) * FROM #SingleReactionCounts
SELECT TOP(100) * FROM #SingleReactionCounts ORDER BY NbReports desc


---------------------------------------------------------
-- ADR-ADR counts
---------------------------------------------------------
IF OBJECT_ID('tempdb..#ReactionReactionCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #ReactionReactionCounts
	CREATE TABLE #ReactionReactionCounts (
		MedDRAPTCodeR1 INT, 
		MedDRAPTCodeR2 INT, 
		NbReports INT, 
		PRIMARY KEY (MedDRAPTCodeR1,MedDRAPTCodeR2)
	)
	INSERT INTO #ReactionReactionCounts
	SELECT R1.MedDRAPTCode, R2.MedDRAPTCode, COUNT(DISTINCT R1.ReportID)
	FROM #ReportReactionList R1
	JOIN #ReportReactionList R2 ON R2.ReportID=R1.ReportID
	WHERE R1.MedDRAPTCode != R2.MedDRAPTCode
	GROUP BY R1.MedDRAPTCode, R2.MedDRAPTCode
END
-- takes 1 min to create 
-- 14,562,320 rows

SELECT COUNT(*) FROM #ReactionReactionCounts
SELECT TOP(100) * FROM #ReactionReactionCounts
SELECT TOP(100) R.* , M1.PT_NAME, M2.PT_NAME 
       FROM #ReactionReactionCounts AS R
       JOIN [Meddra_20200830].[MedDRA].[MEDDRA_MD_HIERARCHY] AS M1 ON R.MedDRAPTCodeR1 = M1.PT_CODE
       JOIN [Meddra_20200830].[MedDRA].[MEDDRA_MD_HIERARCHY] AS M2 ON R.MedDRAPTCodeR2 = M2.PT_CODE
	   WHERE M1.PRIMARY_SOC_FG = 'Y' AND M2.PRIMARY_SOC_FG = 'Y'
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
-- takes 43 seconds to create 
-- 3,465,563 rows

SELECT COUNT(*) FROM #DrugReactionCounts
SELECT TOP(100) * FROM #DrugReactionCounts
SELECT TOP(100) DR.*, P.[Name], M.PT_NAME
	   FROM #DrugReactionCounts AS DR
	   JOIN [WHODrug].[Product] P ON DR.Drecno = P.Drecno
	   JOIN [Meddra_20200830].[MedDRA].[MEDDRA_MD_HIERARCHY] M ON DR.MedDRAPTCode = M.PT_CODE
	   WHERE P.Seq1 = '01' and P.Seq2 = '001' and M.PRIMARY_SOC_FG = 'Y'
	   ORDER BY NbReports desc


---------------------------------------------------------
-- Big count table
---------------------------------------------------------


IF OBJECT_ID('tempdb..#Reaction1And2AllCounts') IS NULL --NOT NULL
	BEGIN
	--DROP TABLE #Reaction1And2AllCounts
	
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
		WHERE Product.[Name] = 'HPV vaccine'
	)
	/*DECLARE @Drug2Drecno char(6) = (
		SELECT DISTINCT Product.Drecno
		FROM [WHODrug].[Product] AS Product
		WHERE Product.[Name] = 'nivolumab'
	)*/

	CREATE TABLE #Reaction1And2AllCounts (
		Drecno varchar(6) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Drug varchar(1500) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		Reaction1 varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		MedDRAPT1 INT,
		--MedDRASOC1 INT ,
		--SOC1 varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		Reaction2 varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS,
		MedDRAPT2 INT,
		--MedDRASOC2 INT ,
		--SOC2 varchar(100) COLLATE SQL_Latin1_General_CP1_CI_AS, 
		n___ INT,
		n1__ INT,
		n_1_ INT,
		n__1 INT,
		n11_ INT,
		n1_1 INT,
		n_11 INT,
		Observed INT,
		Expected INT,
		PRIMARY KEY (Drecno,MedDRAPT1,MedDRAPT2/*, MedDRASOC1, MedDRASOC2*/)
	)
	INSERT INTO #Reaction1And2AllCounts 
	SELECT 
		SingleD.Drecno COLLATE SQL_Latin1_General_CP1_CI_AS AS Drecno, 
		SingleD.DrugName COLLATE SQL_Latin1_General_CP1_CI_AS AS Drug,
		SingleR1.ReactionName AS Reaction1,
		R1.MedDRAPTCode AS MedDRAPT1, 
		--R1.MedDRASOCCode1 ,
		--SingleR1.ReactionNameSOC1 ,
		SingleR2.ReactionName AS Reaction2,
		R2.MedDRAPTCode AS MedDRAPT2, 
		--R2.MedDRASOCCode2 ,
		--SingleR2.ReactionNameSOC2 ,
		@n___ AS n___,
		SingleR1.NbReports AS n1__, 
		SingleR2.NbReports AS n_1_,
		SingleD.NbReports AS n__1,
		RR.NbReports AS n11_,
		DR1.NbReports AS n1_1,
		DR2.NbReports AS n_11,
		COUNT(DISTINCT D.ReportID) AS Observed,
		ResearchProjects.dbo.CxxyExpected(@n___, SingleR1.NbReports, SingleR2.NbReports, SingleD.NbReports, RR.NbReports, DR1.NbReports, DR2.NbReports, COUNT(DISTINCT R1.ReportID)) AS Expected
	FROM #ReportReactionList	R1
	JOIN #ReportReactionList	R2			ON R2.ReportID = R1.ReportID
	JOIN #ReportDrugList		D			ON D.ReportID = R1.ReportID
	JOIN #SingleDrugCounts		SingleD		ON SingleD.Drecno = D.Drecno
	JOIN #SingleReactionCounts	SingleR1	ON SingleR1.MedDRAPTCode = R1.MedDRAPTCode  --and SingleR1.MedDRASOCCode = R1.MedDRASOCCode
	JOIN #SingleReactionCounts	SingleR2	ON SingleR2.MedDRAPTCode = R2.MedDRAPTCode  --and SingleR2.MedDRASOCCode = R2.MedDRASOCCode
	JOIN #ReactionReactionCounts RR			ON RR.MedDRAPTCodeR1 = R1.MedDRAPTCode	AND RR.MedDRAPTCodeR2 = R2.MedDRAPTCode
	JOIN #DrugReactionCounts	DR1			ON DR1.Drecno = D.Drecno	AND DR1.MedDRAPTCode = R1.MedDRAPTCode
	JOIN #DrugReactionCounts	DR2			ON DR2.Drecno = D.Drecno	AND DR2.MedDRAPTCode = R2.MedDRAPTCode
	WHERE 1=1
	  and D.Drecno = @Drug1Drecno
	  and R1.MedDRAPTCode != R2.MedDRAPTCode

	GROUP BY 
		D.Drecno, 
		SingleD.Drecno,
		SingleD.DrugName,
		R1.MedDRAPTCode, 
		SingleR1.ReactionName,
		--R1.MedDRASOCCode,
		--SingleR.ReactionNameSOC,
		R2.MedDRAPTCode, 
		SingleR2.ReactionName,
		--R2.MedDRASOCCode,
		--SingleR2.ReactionNameSOC,
		SingleD.NbReports, 
		SingleR1.NbReports,
		SingleR2.NbReports,
		RR.NbReports,
		DR1.NbReports,
		DR2.NbReports
	ORDER BY Observed DESC
END
-- takes 45 min to create 
-- 1,136,484 rows

SELECT COUNT(*) FROM #Reaction1And2AllCounts
SELECT TOP(100) * FROM #Reaction1And2AllCounts
SELECT * FROM #Reaction1And2AllCounts


-------------------------------------------------------
-- Create result file 
-------------------------------------------------------

SELECT DISTINCT
	Result.Drug,
	--Result.SOC1,
	Result.Reaction1,
	--Result.SOC2,
	Result.Reaction2,
	Result.Observed as NbObserved,
	Result.Expected as NbExpected, 
	ResearchProjects.dbo.ICoe(Result.Observed, Result.Expected) AS Omega, 
	ResearchProjects.dbo.ICoe025(Result.Observed, Result.Expected) AS Omega025,
	Result.n___ as NbVigiBase,
	Result.n1__ as NbReaction1,
	Result.n_1_ as NbReaction2,
	Result.n__1 as NbDrug,
	Result.n11_ as NbReaction1Reaction2,
	Result.n1_1 as NbReaction1Drug,
	Result.n_11 as NbReaction2Drug
FROM #Reaction1And2AllCounts Result
WHERE 1=1
  and Reaction1 < Reaction2 -- remove duplicate rows (where Reaction1 & Reaction2 already exists but as Reaction2 & Reaction1)
  --and ResearchProjects.dbo.ICoe025(Result.Observed, Result.Expected) > 0 -- restriction: only when Omega025 > 0 included in result								
ORDER BY Omega025 DESC
-- takes 15 seconds to create 
-- 568,242 rows


DROP TABLE #ReportDrugList
DROP TABLE #ReportReactionList
DROP TABLE #SingleDrugCounts 
DROP TABLE #SingleReactionCounts 
DROP TABLE #ReactionReactionCounts
DROP TABLE #DrugReactionCounts
DROP TABLE #Reaction1And2AllCounts


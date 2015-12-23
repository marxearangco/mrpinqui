-- --------------------------------------------------------
-- Host:                         192.168.1.58
-- Server version:               5.6.12 - openSUSE package
-- Server OS:                    Linux
-- HeidiSQL Version:             8.0.0.4396
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;

-- Dumping database structure for invndc
DROP DATABASE IF EXISTS `invndc`;
CREATE DATABASE IF NOT EXISTS `invndc` /*!40100 DEFAULT CHARACTER SET latin1 */;
USE `invndc`;


-- Dumping structure for event invndc.ev_invhistory
DROP EVENT IF EXISTS `ev_invhistory`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.3` EVENT `ev_invhistory` ON SCHEDULE EVERY 1 DAY STARTS '2015-09-11 10:00:00' ON COMPLETION PRESERVE ENABLE COMMENT 'rund every day' DO BEGIN
	TRUNCATE TABLE tblitemhistory;
	call sp_invhistory('');
END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_cost
DROP PROCEDURE IF EXISTS `sp_cost`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_cost`(IN `date_start` DATE, IN `date_end` DATE, IN `options` VARCHAR(50))
BEGIN



DECLARE done INT;



DECLARE catid varchar(50);



DECLARE cmd varchar(1000);



DECLARE output_tax double(10,2);



DECLARE net_vat double(10,2);



DECLARE vatdiv float;



DECLARE taxdiv float;



DECLARE sum_qty int;



DROP TEMPORARY TABLE IF EXISTS TEMP;



CREATE TEMPORARY TABLE TEMP (



	dateSO Date,



	soID VARCHAR(15),



	code int,



	itemname VARCHAR(100),



	qty int,



	unit VARCHAR(10),



	unitcost double(10,2),



	discount int,



	amount double(18,2),



	netvat double(18,2),



	outputtax double(18,2),



	category varchar(50),



	remarks varchar(100),



	brand varchar(100),



	suppliercode varchar(10),



	supplier varchar(50),



	sortkey int



);



SET vatdiv = 1/1.12;



SET taxdiv = 12/100;







PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateSO, (



		case 



			when a.soID="0" then 



			case 



				when b.salesInvc = "0" then b.salesOR



			else



				b.salesInvc



			end



		else



			a.soID



		end



		), a.iditem,



	c.Itemname, a.qty, e.Unit, a.cost, a.discount, 



	((a.qty * a.cost)-((a.qty * a.cost)*(discount/100))),



	(((a.qty * a.cost)-((a.qty * a.cost)*(discount/100))) * (1/1.12)), 



	((((a.qty * a.cost)-((a.qty * a.cost)*(discount/100))) * (1/1.12)) * (12/100)), 



	d.Category, b.payMode, 



	UPPER(f.brandname), g.code, UPPER(g.suppliername), 1 



	from tblsales a



	left join tblsalesorder b on b.id=a.id



	left join tblitem c on c.code=a.idItem



	left join tblitemcategory d on d.idCategory = c.idcategory



	left join tblunit e on e.idUnit=c.idUnit



	left join tblitembrand f on f.idbrand = c.idbrand



	left join tblsupplier g on g.idsupplier = c.idsupplier



	where b.dateSO between ? and ?



	order by d.category, b.dateSO, a.soID';



	



set @start = date_start;



set @end = date_end;



EXECUTE stmt1 USING @start, @end;



DEALLOCATE PREPARE stmt1;







PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateRsrv, a.rsrvNo, if







(a.iditem=0,a.idMtrbikes,a.iditem), a.itemname, if(a.qty=0,1,a.qty), if(a.unit="","Unit(s)",a.unit), 







b.downpayment, 0,b.downpayment, 



	(b.downpayment * (1/1.12)) , ((b.downpayment * (1/1.12))* (12/100)), 



	"Acknowledgement Receipt", b.remarks, "CASH COLLECTIONS","AR", "CASH COLLECTIONS", 5



	from tblreserveitems a



	left join tblreserveorder b on a.rsrvNo=b.rsrvNo 



	left join tblitem c on c.iditem=a.iditem



	left join tblitembrand d on d.idbrand=c.idbrand



	left join tblsupplier e on e.idSupplier = c.idSupplier



	where b.dateRsrv between ? and ?



	order by b.dateRsrv, b.rsrvNo';







set @start = date_start;



set @end = date_end;



EXECUTE stmt1 USING @start, @end;



DEALLOCATE PREPARE stmt1;







PREPARE stmt1 FROM 'INSERT INTO TEMP select a.dateSO, a.jeid, 0, b.services,IF







(b.minutes=0,1,b.minutes),



	IF(b.minutes=0, "Unit", "Min(s)"), IF(b.minutes=0, b.charge, c.flatRate),



	ifnull(c.srvcdscnt,0), IF(b.minutes=0,b.charge,((b.minutes/60)*c.flatRate)), 



	IF(b.minutes=0,(b.charge*(1/1.12)),(((b.minutes/60)*c.flatRate) * 1/1.12)), 



	IF(b.minutes=0,(b.charge*(1/1.12)*12/100),((((b.minutes/60)*c.flatRate) * (1/1.12))* 







(12/100))),



	"Service Labor & Materials", "Service", "SERVICE LABOR", "SVC","SERVICE",4 



	from tblsalesorder a 



	left join tbljoborder c on c.jeid = a.jeid



	left join tbljoservices b on b.idjo = c.idjo



	where a.dateSO between ? and ? and c.status in("done","sold") and a.jeid is not null and 







a.jeid <> "0"



	order by a.dateSO, a.jeid';







set @start = date_start;



set @end = date_end;







EXECUTE stmt1 USING @start, @end;



DEALLOCATE PREPARE stmt1;







UPDATE TEMP SET SORTKEY = 3, brand='CONSIGNED ITEMS', supplier ='CONSIGNED ITEMS' WHERE CATEGORY 







LIKE '%consign%';



if options = 'summary' then



	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;



	CREATE TEMPORARY TABLE TEMPSUM (



		category varchar(50),



		cost double(18,2),



		quantity int,



		cash double(18,2),



		charge double(18,2),



		advertising double(18,2),



		sortkey int



	);







	INSERT INTO TEMPSUM SELECT category, sum(amount), if(category = "Service Labor & 







Materials",count(qty),sum(qty)),



		0,0,0,sortkey



	from TEMP GROUP BY category, sortkey;







	UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks not like 







'%charge%' and b.remarks not like '%advertising%') and b.category = a.category);



	UPDATE TEMPSUM a SET a.charge = (select sum(b.amount) from TEMP b where b.remarks like 







'%charge%' and b.category = a.category);



	UPDATE TEMPSUM a SET a.advertising = (select sum(b.amount) from TEMP b where b.remarks like 







'%advertising%' and b.category = a.category);



	SELECT * FROM TEMPSUM ORDER BY sortkey, category;







elseif options = 'brand' then



	BEGIN



	UPDATE TEMP SET SORTKEY = 2 WHERE BRAND LIKE '%other%';



	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;



		CREATE TEMPORARY TABLE TEMPSUM (



			brand varchar(50),



			cost double(18,2),



			quantity int,



			cash double(18,2),



			charge double(18,2),



			advertising double(18,2),



			sortkey int



		);



		INSERT INTO TEMPSUM SELECT brand, sum(amount), if(brand = "SERVICE LABOR",count







(qty),sum(qty)),



			0,0,0,sortkey



			from TEMP GROUP BY brand, sortkey;







		UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks not 







like '%charge%' and b.remarks not like '%advertising%') and b.brand = a.brand);



		UPDATE TEMPSUM a SET a.charge = (select sum(b.amount) from TEMP b where b.remarks 







like '%charge%' and b.brand = a.brand);



		UPDATE TEMPSUM a SET a.advertising = (select sum(b.amount) from TEMP b where 







b.remarks like '%advertising%' and b.brand = a.brand);



		SELECT * FROM TEMPSUM ORDER BY SORTKEY, BRAND;



	END;







elseif options = 'supplier' then



	BEGIN



	UPDATE TEMP SET SORTKEY = 2 WHERE supplier LIKE '%other%';



	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;



		CREATE TEMPORARY TABLE TEMPSUM (



			supplier varchar(50),



			cost double(18,2),



			quantity int,



			cash double(18,2),



			charge double(18,2),



			advertising double(18,2),



			sortkey int



		);



		INSERT INTO TEMPSUM SELECT supplier, sum(amount), if(brand = "SERVICE LABOR",count







(qty),sum(qty)),



			0,0,0,sortkey



			from TEMP GROUP BY sortkey,supplier;







		UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks not 







like '%charge%' and b.remarks not like '%advertising%') and b.supplier = a.supplier);



		UPDATE TEMPSUM a SET a.charge = (select sum(b.amount) from TEMP b where b.remarks 







like '%charge%' and b.supplier = a.supplier);



		UPDATE TEMPSUM a SET a.advertising = (select sum(b.amount) from TEMP b where 







b.remarks like '%advertising%' and b.supplier = a.supplier);



		



		SELECT * FROM TEMPSUM ORDER BY SORTKEY, supplier;



	END;







else



	if options = 'bySupplier'	then



		SELECT * FROM TEMP order by sortkey, supplier,dateSO, SOid;



	elseif options ='byBrand' then



		SELECT * FROM TEMP order by sortkey, brand, dateSO, SOid;



	elseif options ='byCategory' then



		SELECT * FROM TEMP order by sortkey, category, dateSO, SOid;



	else



		SELECT * FROM TEMP order by sortkey, dateSO, SOid;



	end if;







end if;







END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_costofsales
DROP PROCEDURE IF EXISTS `sp_costofsales`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_costofsales`(IN `date_start` vARCHAR(50), IN `date_end` vARCHAR(50), IN `options` vARCHAR(50))
BEGIN
/*
=============================================
UPDATED BY: MCA 12.08.2015
-- payment mode

=============================================
*/
DECLARE done INT;
DECLARE catid varchar(50);
DECLARE cmd varchar(1000);
DECLARE sum_qty int;
DROP TEMPORARY TABLE IF EXISTS TEMP;
CREATE TEMPORARY TABLE TEMP (
	dateSO Date,
	soID VARCHAR(15),
	itemname VARCHAR(250),
	qty varchar(20),
	unit VARCHAR(10),
	unitCost double(10,2),
	discount int,
	amount double(18,2),
	category varchar(250),
	remarks varchar(1000),
	brand varchar(250),
	suppliercode varchar(10),
	supplier varchar(150),
	sortkey int
);
PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateSO, 
		(
		case 
			when a.soID="0" then 
			case 
				when b.salesInvc = "0" then b.salesOR
			else
				b.salesInvc
			end
		else
			a.soID
		end
		), c.Itemname, a.qty, e.Unit, c.cost, a.discount, 
		(a.qty*c.cost)-((a.qty*c.cost)*(a.discount/100)),
		d.Category, concat(b.payMode," - ",b.type), UPPER(f.brandname), g.code, UPPER(g.suppliername), 1 
		from tblsales a
left join tblsalesorder b on a.id=b.id
left join tblitem c on a.idItem=c.code
left join tblitemcategory d on d.idCategory = c.idcategory
left join tblunit e on e.idUnit=c.idUnit
left join tblitembrand f on f.idbrand = c.idbrand
left join tblsupplier g on g.idsupplier = c.idsupplier
where b.dateSO between ? and ?
order by d.category, b.dateSO, a.soID';
set @start = date_start;
set @end = date_end;
EXECUTE stmt1 USING @start, @end;
DEALLOCATE PREPARE stmt1;
PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateRsrv, a.rsrvNo, UPPER(a.itemname), a.qty, a.unit, 
a.amount, 0,a.amount, "Acknowledgement Receipt", concat(b.payMode," - ",b.type), "CASH COLLECTIONS","AR", "CASH COLLECTIONS", 5
from tblreserveitems a
left join tblreserveorder b on a.rsrvNo=b.rsrvNo 
left join tblitem c on c.iditem=a.iditem
left join tblitembrand d on d.idbrand=c.idbrand
left join tblsupplier e on e.idSupplier = c.idSupplier
where b.dateRsrv between ? and ?
order by b.dateRsrv, b.rsrvNo';
set @start = date_start;
set @end = date_end;
EXECUTE stmt1 USING @start, @end;
DEALLOCATE PREPARE stmt1;
PREPARE stmt1 FROM 'INSERT INTO TEMP select c.dateSO, a.jeid, UPPER(concat(b.lName,", ", b.fName," ", if(b.midInit="","",concat(b.midInit,".")))), ROUND((a.minutes/60),2), if((a.minutes/60)="0", "","hr(s)"),
		if(a.minutes=0,0,a.flatRate),(a.srvcDscnt + a.partDscnt),
		(a.srvcTotal-a.srvcDscnt),  "Service Labor & Materials", concat(c.payMode," - ",c.type), "SERVICE LABOR", "SVC","SERVICE",4 
		from tbljoborder a
left join tblcustomer b on b.idcustomer = a.idCustomer
left join tblsalesorder c on a.jeid = c.jeid
where a.status ="sold" and (c.dateSO between ? and ?)
order by c.dateSO, a.jeid';
Set @start = date_start;
set @end = date_end;
EXECUTE stmt1 USING @start, @end;
DEALLOCATE PREPARE stmt1;
UPDATE TEMP SET SORTKEY = 3, brand='CONSIGNED ITEMS', supplier ='CONSIGNED ITEMS' 
WHERE category LIKE '%consign%';
UPDATE TEMP SET unit ="-", unitCost=amount where qty =0;
if options = 'summary' then
	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;
	CREATE TEMPORARY TABLE TEMPSUM (
		category varchar(50),
		amount double(18,2),
		quantity varchar(20),
		cash double(18,2),
		charge double(18,2),
		advertising double(18,2),
		sortkey int
	);
		INSERT INTO TEMPSUM SELECT category, sum(amount),sum(qty),
				0,0,0,sortkey
				from TEMP GROUP BY category, sortkey;
			UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks not like 
				'%charge%' and b.remarks not like '%advertising%') and b.category = a.category);
	UPDATE TEMPSUM a SET a.charge = (select sum(b.amount) from TEMP b where b.remarks like 
		'%charge%' and b.category = a.category);
	UPDATE TEMPSUM a SET a.advertising = (select sum(b.amount) from TEMP b where b.remarks like 
		'%advertising%' and b.category = a.category);
	SELECT * FROM TEMPSUM ORDER BY category, SORTKEY;
	elseif options = 'brand' then
		BEGIN
		UPDATE TEMP SET SORTKEY = 2 WHERE BRAND LIKE '%other%';
		DROP TEMPORARY TABLE IF EXISTS TEMPSUM;
			CREATE TEMPORARY TABLE TEMPSUM (
				brand varchar(50),
				amount double(18,2),
				quantity varchar(20),
				cash double(18,2),
				charge double(18,2),
				advertising double(18,2),
				sortkey int
			);
				INSERT INTO TEMPSUM SELECT brand, sum(amount),sum(qty),
							0,0,0,sortkey
							from TEMP GROUP BY brand, sortkey;
					UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks not 
						like '%charge%' and b.remarks not like '%advertising%') and b.brand = a.brand);
		UPDATE TEMPSUM a SET a.charge = (select sum(b.amount) from TEMP b where b.remarks 
			like '%charge%' and b.brand = a.brand);
		UPDATE TEMPSUM a SET a.advertising = (select sum(b.amount) from TEMP b where 
			b.remarks like '%advertising%' and b.brand = a.brand);
		SELECT * FROM TEMPSUM ORDER BY SORTKEY, BRAND;
	END;
	elseif options = 'supplier' then
		BEGIN
		UPDATE TEMP SET SORTKEY = 2 WHERE supplier LIKE '%other%';
		DROP TEMPORARY TABLE IF EXISTS TEMPSUM;
			CREATE TEMPORARY TABLE TEMPSUM (
				supplier varchar(50),
				amount double(18,2),
				quantity varchar(20),
				cash double(18,2),
				charge double(18,2),
				advertising double(18,2),
				sortkey int
			);
				INSERT INTO TEMPSUM SELECT supplier, sum(amount),sum(qty),
							0,0,0,sortkey
							from TEMP GROUP BY sortkey,supplier;
					UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks not 
						like '%charge%' and b.remarks not like '%advertising%') and b.supplier = a.supplier);
		UPDATE TEMPSUM a SET a.charge = (select sum(b.amount) from TEMP b where b.remarks 
			like '%charge%' and b.supplier = a.supplier);
		UPDATE TEMPSUM a SET a.advertising = (select sum(b.amount) from TEMP b where 
			b.remarks like '%advertising%' and b.supplier = a.supplier);
		SELECT * FROM TEMPSUM ORDER BY SORTKEY, supplier;
	END;
	else
		if options = 'bySupplier'	then
			SELECT * FROM TEMP order by sortkey, supplier,dateSO, SOid;
		elseif options ='byBrand' then
			SELECT * FROM TEMP order by sortkey, brand, dateSO, SOid;
		elseif options ='byCategory' then

		BEGIN
		DECLARE cat varchar(250);
		DECLARE cur CURSOR FOR SELECT distinct category from TEMP WHERE category is not null order by sortkey, category, dateSO, SOid;
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
		DROP TEMPORARY TABLE IF EXISTS TEMPFIN;
		CREATE TEMPORARY TABLE TEMPFIN (
			category varchar(250),
			dateSO Date,
			soID VARCHAR(15),
			itemname VARCHAR(250),
			qty varchar(20),
			unit VARCHAR(10),
			unitCost double(10,2),
			discount int,
			amount double(18,2),
			remarks varchar(1000),
			brand varchar(250),
			pkey int
		);

		OPEN cur;
		 SET done = 0;
		   read_loop: LOOP
		    FETCH cur INTO cat;
		    IF done THEN
		    	LEAVE read_loop;
		    END IF;
			 INSERT TEMPFIN (category, pkey) select cat,1;

			 INSERT TEMPFIN
			 SELECT NULL, dateSO, soID, itemname, qty, unit, unitCost, discount, amount, remarks, brand,null
			 FROM TEMP
			 WHERE category = cat;

			 INSERT TEMPFIN (itemname,qty,amount, pkey) select "TOTAL",sum(qty),sum(amount),2 from TEMP where category = cat;
			 INSERT TEMPFIN (category) select NULL;
		END LOOP;
		CLOSE cur;
	--	SELECT * FROM TEMP order by sortkey, category, dateSO, SOid;
	--	SELECT distinct category from TEMP order by category, dateSO, SOid;
		SELECT * FROM TEMPFIN;
		end;
		else
			SELECT * FROM TEMP order by sortkey, dateSO, SOid;
		end if;
		end if;
END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_fixdiscount
DROP PROCEDURE IF EXISTS `sp_fixdiscount`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_fixdiscount`()
BEGIN
DROP TABLE IF EXISTS TEMP;
CREATE TEMPORARY TABLE TEMP
(
	id int,
	soidsales varchar(15),
	soidorder varchar(15),
	qty int,
	unitprice double(18,2),
	itemamount double(18,2),
	itemdiscount double(18,2),
	itemdiscountamount float,
	totaldiscount double(18,2),
	remarks varchar(15),
	itemmount double(18,2), 
	totalamount double(18,2),
	fortotaldiscount double(18,2),
	fortotalamount double(18,2)
);

DROP TABLE IF EXISTS TEMP2;
CREATE TEMPORARY TABLE TEMP2
(
	id int,
	soid varchar(15),
	fortotaldiscount double(18,2),
	fortotalamount double(18,2)
);

INSERT INTO TEMP
select a.id, a.soid, b.soid, b.qty, b.unitPrice, (b.qty * b.unitprice), b.discount, 0 , 
a.totaldiscount, if(b.discount=a.totaldiscount,'true','false'), b.amount, a.total, 0,0
from tblsales b 
left join tblsalesorder a on a.soID=b.soid;

UPDATE TEMP SET itemdiscountamount=ifnull(itemamount*(itemdiscount/100),0);

INSERT INTO TEMP2 SELECT distinct id, soidsales, 0, 0 from TEMP;

UPDATE TEMP2 a
SET fortotaldiscount=(select sum(itemdiscountamount) from TEMP b where a.soid = b.soidsales);


UPDATE TEMP2 a
SET fortotalamount=(select sum(itemamount)-sum(itemdiscount) from TEMP b where a.soid = 
b.soidsales);







select * from TEMP;



update tblsalesorder a left join TEMP2 b on a.soid = b.soID and a.id = b.id



set a.totaldiscount = b.fortotaldiscount, a.total=b.fortotalamount;



select a.id, a.soid, b.soid, a.fortotaldiscount, b.totaldiscount, a.fortotalamount, b.total from 







TEMP2 a 



left join tblsalesorder b on a.soid = b.soID and a.id = b.id;



-- select * from TEMP where remarks='false';















END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_fixinventory
DROP PROCEDURE IF EXISTS `sp_fixinventory`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_fixinventory`(IN `pcode` INT, IN `options` vaRCHAR(50), IN `beg` INT, IN `p_in` INT, IN `p_out` INT, IN `p_end` INT)
BEGIN



IF options ="select" then

	begin

		call sp_invhistory(pcode, 'out');

		select c.begbalance as BEG, sum(a.qtyin) as QtyIN, sum(a.qtyout) as QtyOUT, b.qtyEnd as QtyEnd from TEMP2 a

		left join tblinventory b on a.code = b.code

		left join tblitem c on a.code = c.code;

	end;

Elseif options = "update" then

	begin

		update tblitem set begbalance = beg where code = pcode;

		update tblinventory set qtybeg = beg, qtyIn = p_in, qtyout = p_out, qtyend = p_end where code = pcode;

		select concat("Item Code ", pcode, " has already been updated!") as Message;

	end;

end if;

END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_invcostingledger
DROP PROCEDURE IF EXISTS `sp_invcostingledger`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_invcostingledger`(IN `paramcode` VARCHAR(50), IN `paramoptions` vaRCHAR(50))
BODY: BEGIN
DECLARE done INT;
DECLARE done2 INT;
DECLARE codex int;
DECLARE datetransx date;
DECLARE datex date;
DECLARE endingx double(18,2);
DECLARE idex int;
DECLARE minx int;
DROP TABLE IF EXISTS TEMP;
CREATE TEMPORARY TABLE TEMP(
	id int NOT NULL AUTO_INCREMENT,
	code varchar(250),
	transdate Date,
	qtyBeg int,
	begCost double(18,2),
	begVal double(18,2),
	qtyIn int,
	InCost double(18,2),
	InVal double(18,2),
	qtyOut int,
	outSRP double(18,2),
	OutSRPVal double(18,2),
	OutCost double(18,2),
	OutCostVal double(18,2),
	qtyPOut int,
	POutCost double(18,2),
	POutVal double(18,2),	
	qtyEnd int,
	remarks varchar(50),
	itemname varchar(250),
	   PRIMARY KEY (`id`)
	)  ENGINE=InnoDB AUTO_INCREMENT=2378 DEFAULT CHARSET=utf8;
if paramoptions = "byCategory" then
	BEGIN
	INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	select a.code,IFNULL(b.dateinput, '0000-00-00'), IFNULL(b.begbalance,0), b.cost, (b.cost * b.begBalance), 0,0,0,0,0,0,0,0,0,0,0,IFNULL(b.begbalance,0), "Beginning",b.itemName
	from tblinventory a
	left join tblitem b on a.code = b.code
	where b.idCategory = paramcode and b.begbalance <> 0
	order by b.dateinput;
		INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	select a.idItem,IFNULL(b.dateReceived, '0000-00-00'), 0,0,0, IFNULL(a.qtyreceived,0), a.cost,(a.qtyreceived*a.cost),0,0,0,0,0,0,0,0,0, concat("Receiving (",b.roID,")"), c.itemName
	FROM tblordereditems a
	left join tblorder b on b.idorder = a.idOrder
	left join tblitem c on a.idItem = c.code
	where c.idCategory = paramcode
	order by a.dateReceived;
		INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	SELECT a.idItem,IFNULL(b.dateSO, '0000-00-00'), 0,0,0,0,0,0,IFNULL(a.qty,0), a.unitPrice, (a.qty*a.unitPrice), c.cost,(a.qty * c.cost), 0,0,0,0, concat("SO (",b.soID,")"),c.itemName
	from tblsales a
	left join tblsalesorder b on b.id = a.id and b.soID = a.soID
	left join tblitem c on c.code = a.idItem
	where c.idCategory = paramcode
	order by b.dateSO;
		INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	SELECT a.idItem,IFNULL(b.datePullOut, '0000-00-00'), 0,0,0,0,0,0,0,0,0,0,0, IFNULL(a.qty,0), c.cost,(a.qty * c.cost),0, concat("Pullout (",b.pulloutID,")"),c.itemName
	from tblpulloutitems a 
	left join tblpullout b on a.idPullOut = b.idPullOut
	left join tblitem c on a.idItem = c.code
	where c.idCategory = paramcode
	order by b.datePullOut;
	END;
	else
	BEGIN
	INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	select a.code,IFNULL(b.dateinput, '0000-00-00'), IFNULL(b.begbalance,0), b.cost, (b.cost * b.begBalance), 0,0,0,0,0,0,0,0,0,0,0,IFNULL(b.begbalance,0), "Beginning",b.itemName
	from tblinventory a
	left join tblitem b on a.code = b.code
	where a.code = paramcode
	order by b.dateinput;
		INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	select a.idItem,IFNULL(b.dateReceived, '0000-00-00'), 0,0,0, IFNULL(a.qtyreceived,0), a.cost,(a.qtyreceived*a.cost),0,0,0,0,0,0,0,0,0, concat("Receiving (",b.roID,")"), c.itemName
	FROM tblordereditems a
	left join tblorder b on b.idorder = a.idOrder
	left join tblitem c on a.idItem = c.code
	where a.iditem = paramcode
	order by a.dateReceived;
		INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	SELECT a.idItem,IFNULL(b.dateSO, '0000-00-00'), 0,0,0,0,0,0,IFNULL(a.qty,0), a.unitPrice, (a.qty*a.unitPrice), c.cost,(a.qty * c.cost), 0,0,0,0, concat("SO (",b.soID,")"),c.itemName
	from tblsales a
	left join tblsalesorder b on b.id = a.id and b.soID = a.soID
	left join tblitem c on c.code = a.idItem
	where a.idItem = paramcode
	order by b.dateSO;
		INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	SELECT a.idItem,IFNULL(b.datePullOut, '0000-00-00'), 0,0,0,0,0,0,0,0,0,0,0, IFNULL(a.qty,0), c.cost,(a.qty * c.cost),0, concat("Pullout (",b.pulloutID,")"),c.itemName
	from tblpulloutitems a 
	left join tblpullout b on a.idPullOut = b.idPullOut
	left join tblitem c on a.idItem = c.code
	where a.idItem = paramcode
	order by b.datePullOut;
	END;
	end if;
DROP TABLE IF EXISTS TEMP2;
CREATE TEMPORARY TABLE TEMP2 (
	id int NOT NULL AUTO_INCREMENT,
	code varchar(250),
	transdate Date,
	qtyBeg int,
	begCost double(18,2),
	begVal double(18,2),
	qtyIn int,
	InCost double(18,2),
	InVal double(18,2),
	qtyOut int,
	OutSRP double(18,2),
	OutSRPVal double(18,2),
	OutCost double(18,2),
	OutCostVal double(18,2),
	qtyPOut int,
	POutCost double(18,2),
	POutVal double(18,2),
	qtyEnd int,
	remarks varchar(50),
	itemname varchar(250),
	
	   PRIMARY KEY (`id`)
	)  ENGINE=InnoDB AUTO_INCREMENT=2378 DEFAULT CHARSET=utf8;
INSERT INTO TEMP2(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
select code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname
FROM TEMP ORDER BY transdate;
TRUNCATE TABLE TEMP;
BEGIN
DECLARE cur CURSOR FOR SELECT distinct CODE FROM TEMP2 order by itemname;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
set endingx = 0;
OPEN cur;
 SET done = 0;
   read_loop: LOOP
	    FETCH cur INTO codex;
	    IF done THEN
	    	LEAVE read_loop;
	    END IF;
		 	BEGIN
			DECLARE cur2 CURSOR FOR SELECT id FROM TEMP2 where code = codex order by id;
			DECLARE CONTINUE HANDLER FOR NOT FOUND SET done2 = 1;
			set minx = (select min(id) from TEMP2 WHERE code = codex);
			set endingx = (select qtyend from TEMP2 WHERE id = minx and code = codex );
			OPEN cur2;
			 SET done2 = 0;
			   read_loop2: LOOP
				    FETCH cur2 INTO idex;
				    IF done2 THEN
				    	LEAVE read_loop2;
				    END IF;
		    		 	 UPDATE TEMP2 SET qtybeg = endingx
						 WHERE code = codex and id=idex;
						 UPDATE TEMP2 SET qtyend = (qtybeg + qtyin - qtyout - qtyPout)
						 WHERE code = codex and id=idex;
						 set endingx = (select qtyend FROM TEMP2 WHERE id=idex and code = codex);
			   END LOOP;
			CLOSE cur2;
			END;
	INSERT INTO TEMP(code,itemname) select concat(codex," - ",itemname), 1 from TEMP2 where code = codex limit 1;
	
	INSERT INTO TEMP(code,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname) 
	select null,transdate, qtyBeg, begCost, begVal, qtyIn, InCost, InVal, qtyOut, OutSRP, OutSRPVal, OutCost, OutCostVal,qtyPOut, POutCost, POutVal, qtyEnd, remarks, itemname
   FROM TEMP2 WHERE code = codex;
	
	INSERT INTO TEMP(code) select null;
	END LOOP;
	CLOSE cur;
END;
select code,
		 transdate, 
       qtyBeg, 
		 begCost, 
		 begVal, 
		 qtyIn, 
		 InCost, 
		 InVal, 
		 qtyOut, 
		 OutSRP, 
		 OutSRPVal, 
		 OutCost, 
		 OutCostVal,
		 qtyPOut, 
		 POutCost, 
		 POutVal, 
		 qtyEnd, 
		 remarks, 
		 itemname 
		 from TEMP;
END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_inventoryreport
DROP PROCEDURE IF EXISTS `sp_inventoryreport`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_inventoryreport`(IN `paramcode` vARCHAR(50))
BEGIN































DECLARE done INT;















DECLARE done2 INT;















DECLARE codex int;















DECLARE datetransx date;















DECLARE datex date;















DECLARE endingx double(18,2);















DROP TABLE IF EXISTS TEMP;















CREATE TEMPORARY TABLE TEMP (















	transdate Date,















	code INT,















	mnemonic varchar(20),















	beg int,















	qtyin int,















	qtyout int,















	ending int,















	amount double(18,2),















	category varchar(50),















	id varchar(15),















	remarks varchar(100)















);















if paramcode = '' or paramcode='all' then















	INSERT INTO TEMP select '0000-00-00',code,'BEG', qtybeg,0,0,qtybeg,cost,null,0, 'Beginning' 







FROM tblinventory;-- where code = paramcode;















	INSERT INTO TEMP select dateReceived,iditem,'RCV', null,qtyreceived,0,0,cost,null,idorder, 







'Receiving' FROM tblordereditems where status='received';-- and iditem=paramcode;















	INSERT INTO TEMP SELECT NULL,iditem, 'SO',null,0,qty,0,unitprice,null,soID,'Sales' from 







tblsales;-- where iditem=paramcode;















	INSERT INTO TEMP SELECT NULL,iditem, 'POut',null,0, qty,0,unitprice,null,pulloutID, 







'Pullout' from tblpulloutitems;-- where iditem=paramcode;















else















	INSERT INTO TEMP select '0000-00-00',code,'BEG', qtybeg,0,0,qtybeg,cost,null,0, 'Beginning' 







FROM tblinventory where code = paramcode;















	INSERT INTO TEMP select dateReceived,iditem,'RCV', null,qtyreceived,0,0,cost,null,idorder, 







'Receiving' FROM tblordereditems where status='received' and iditem=paramcode;















	INSERT INTO TEMP SELECT NULL,iditem, 'SO',null,0,qty,0,unitprice,null,soID,'Sales' from 







tblsales where iditem=paramcode;















	INSERT INTO TEMP SELECT NULL,iditem, 'POut',null,0, qty,0,unitprice,null,pulloutID, 







'Pullout' from tblpulloutitems where iditem=paramcode;















end if;































UPDATE TEMP a left join tblorder b on a.id = b.idorder 















set a.transdate=b.dateReceived, a.id = b.roID where a.mnemonic ='RCV';































UPDATE TEMP a left join tblsalesorder b on a.id = b.soid 















set a.transdate=b.dateSO where a.mnemonic ='SO';































UPDATE TEMP a left join tblpullout b on a.id = b.pulloutID















set a.transdate=b.datePullOut where a.mnemonic ='POut';































UPDATE TEMP a 















left join tblitem b on a.code = b.code















left join tblitemcategory c on b.idCategory = c.idCategory















set a.category = c.Category; 































DROP TABLE IF EXISTS TEMP2;















CREATE TEMPORARY TABLE TEMP2 (































	transdate Date,















	code INT,















	mnemonic varchar(20),















	beg int,















	qtyin int,















	qtyout int,















	ending int,















	amount double(18,2),















	category varchar(50),















	id varchar(15),















	remarks varchar(100)































);















INSERT INTO TEMP2 SELECT * FROM TEMP ORDER BY transdate;















BEGIN















DECLARE cur CURSOR FOR SELECT distinct CODE FROM TEMP2;















DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;































OPEN cur;















 SET done = 0;















   read_loop: LOOP















	    FETCH cur INTO codex;















	    IF done THEN















	    	LEAVE read_loop;















	    END IF;































		 	BEGIN















			DECLARE cur2 CURSOR FOR SELECT transdate FROM TEMP2 where code = codex order 







by transdate;















			DECLARE CONTINUE HANDLER FOR NOT FOUND SET done2 = 1;















			-- set datex = 0;















			set endingx = (select ending from TEMP2 WHERE MNEMONIC = 'BEG' and code = 







codex limit 1);















			















			OPEN cur2;















			 SET done2 = 0;















			   read_loop2: LOOP















				    FETCH cur2 INTO datetransx;















				    IF done2 THEN















				    	LEAVE read_loop2;















				    END IF;















 				    	 set datex = datetransx;















					 	 UPDATE TEMP2 SET beg = endingx















						 WHERE code = codex and transdate = datetransx;















						 















						 UPDATE TEMP2 SET ending = (beg + qtyin - qtyout)















						 WHERE code = codex and transdate = datetransx;















						 















					 	 















         		    set endingx = (select ending FROM TEMP2 WHERE transdate = datex and code 







= codex limit 1);















			      















				END LOOP;















			CLOSE cur2;















			END;















       















	 	  	 















	END LOOP;















CLOSE cur;















END;































-- SELECT * FROM TEMP ORDER BY transdate;















if paramcode = '' or paramcode='all' then















	SELECT * FROM TEMP2;















else















	select * from TEMP2 WHERE CODE = paramcode;















	-- select * from TEMP WHERE CODE = paramcode;















end if;































































END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_invhistory
DROP PROCEDURE IF EXISTS `sp_invhistory`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_invhistory`(IN `paramcode` vARCHAR(50), IN `paramethod` VARCHAR(5))
BODY: BEGIN
/* UPDATED 12.4.2015 BY MCA
====================================================
REMARKS: added SRP, Cost & itemName
====================================================
*/
DECLARE done INT;
DECLARE done2 INT;
DECLARE codex int;
DECLARE datetransx date;
DECLARE datex date;
DECLARE endingx double(18,2);
DECLARE idex int;
DECLARE minx int;
DROP TABLE IF EXISTS TEMP;
CREATE TEMPORARY TABLE TEMP (
	id int NOT NULL AUTO_INCREMENT,
	transdate Date,
	transid int,
	transNo varchar(20),
	transdesc varchar(20),
	code INT,
	qtybeg int,
	qtyin int,
	qtyout int,
	qtyend int,
	amount double(18,2),
	cost double(18,2),
	srp double(18,2),	
	unit varchar(10),
	idcategory int,
	idbrand int,
	idSupplier int,
	remarks varchar(100),
	partNum varchar(50),
	status varchar(50),
	transby varchar(50),
	itemName varchar(100),
   PRIMARY KEY (`id`)
	)  ENGINE=InnoDB AUTO_INCREMENT=2378 DEFAULT CHARSET=utf8;
if paramcode = '' or paramcode='all' then
	/*
	select 'No parameter' as Message;
	Leave BODY;
	*/
		INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status,partNum,transby,itemName) 
			select IFNULL(b.dateinput, '0000-00-00'), 0,0, 'BEG',a.code,IFNULL(b.begbalance, 0),
					0, 0, IFNULL(b.begbalance,0), a.cost, a.cost, a.srp, b.idunit,b.idCategory, b.idBrand,
					b.idSupplier, 'Beginning', null, b.partNum, 'system',b.itemName
			from tblinventory a
			left join tblitem b on a.code = b.code
			order by b.dateinput;
		INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partNum,transby,itemName) 
			select  IFNULL(b.dateReceived, '0000-00-00'), a.idorder, ifnull(b.roID,'0'), 'RCV', a.iditem, 0,IFNULL(a.qtyreceived, 0),0,0,a.cost, d.cost, d.srp, a.idUnit,
				 c.idCategory, c.idBrand, c.idSupplier, 'Receiving', null, c.partNum,b.receivedBy,c.itemName
			FROM tblordereditems a
			left join tblorder b on b.idorder = a.idOrder
			left join tblitem c on a.idItem = c.code
			left join tblinventory d on a.idItem = d.code
			where a.status='received'
			order by a.dateReceived;
				
			INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partnum,transby,itemName)
			SELECT IFNULL(b.dateSO, '0000-00-00'), a.id, (
					case
						when a.idMtrbikes <> 0 then b.salesInvc
						when b.jeid !='' and b.jeid!='0' then b.jeid
					else
						a.soID
					end)
					, (
					case
						when a.idMtrbikes <> 0 then 'INV'
						when b.jeid !='' and b.jeid!='0' then 'SVC'
					else
						'SO'
					end), a.iditem, 0, 0, 
					IFNULL(a.qty,0), 0, a.unitprice, d.cost, d.srp, c.idunit, c.idCategory, c.idBrand,
					c.idSupplier, 'Sales', null,c.partNum,b.preparedBy,c.itemName
			from tblsales a
			left join tblsalesorder b on b.id = a.id and b.soID = a.soID
			left join tblitem c on c.code = a.idItem
			left join tblinventory d on a.idItem = d.code
		 	order by b.dateSO;
 		INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partNum,transby,itemName)
 			SELECT IFNULL(b.datePullOut, '0000-00-00'), a.idPullOut, a.pulloutid, 'POut', a.idItem, 
 					0, 0, IFNULL(a.qty, 0), 0,a.unitPrice, d.cost, d.srp, c.idUnit, c.idCategory, c.idBrand,
 					c.idSupplier, 'Pullout', null, c.partNum,b.preparedBy,c.itemName
 			from tblpulloutitems a 
 			left join tblpullout b on a.idPullOut = b.idPullOut
 			left join tblitem c on a.idItem = c.code
 			left join tblinventory d on a.idItem = d.code
 			order by b.datePullout;
 		else
 			INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partNum,transby,itemName) 
 			select IFNULL(b.dateinput, '0000-00-00'), 0,0, 'BEG',a.code,IFNULL(b.begbalance,0),
 					0, 0, IFNULL(b.begbalance,0), a.cost, a.cost, a.srp, b.idunit,b.idCategory, b.idBrand,
 					b.idSupplier, 'Beginning', null, b.partNum, 'system',b.itemName
 			from tblinventory a
 			left join tblitem b on a.code = b.code
 			where a.code = paramcode
 			order by b.dateinput;
		INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status,partNum,transby,itemName) 
			select IFNULL(b.dateReceived, '0000-00-00'), a.idorder, b.roID, 'RCV', a.iditem, 0,IFNULL(a.qtyreceived,0),0,0,a.cost,d.cost,d.srp,a.idUnit,
				 c.idCategory, c.idBrand, c.idSupplier, 'Receiving', null,c.partNum,b.receivedBy,c.itemName  
			FROM tblordereditems a
			left join tblorder b on b.idorder = a.idOrder
			left join tblitem c on a.idItem = c.code
			left join tblinventory d on a.idItem = d.code
			where a.status='received' and a.iditem=paramcode
			order by a.dateReceived;
		INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partnum,transby,itemName)
			SELECT IFNULL(b.dateSO, '0000-00-00'), a.id, (
					case
						when a.idMtrbikes <> 0 then b.salesInvc
						when b.jeid !='' and b.jeid!='0' then b.jeid
					else
						a.soID
					end)
					, (
					case
						when a.idMtrbikes <> 0 then 'INV'
						when b.jeid !='' and b.jeid!='0' then 'SVC'
					else
						'SO'
					end), a.iditem, 0, 0, 
					IFNULL(a.qty,0), 0, a.unitprice, d.cost,d.srp, c.idunit, c.idCategory, c.idBrand,
					c.idSupplier, 'Sales', null,c.partNum, b.preparedBy,c.itemName   
			from tblsales a
			left join tblsalesorder b on b.id = a.id and b.soID = a.soID
			left join tblitem c on c.code = a.idItem
			left join tblinventory d on a.idItem = d.code
		 	where a.iditem=paramcode
			order by b.dateSO;
			INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partnum,transby,itemName)
	SELECT IFNULL(b.datePullOut, '0000-00-00'), a.idPullOut, a.pulloutid, 'POut', a.idItem, 
			0, 0, IFNULL(a.qty,0), 0,a.unitPrice, d.cost, d.srp, c.idunit, c.idCategory, c.idBrand, 
			c.idSupplier, 'Pullout', null,c.partNum, b.preparedBy,c.itemName  
	from tblpulloutitems a 
	left join tblpullout b on a.idPullOut = b.idPullOut
	left join tblitem c on a.idItem = c.code
	left join tblinventory d on a.idItem = d.code
 	where a.iditem=paramcode
	order by b.datePullOut;
	end if;
	UPDATE TEMP z LEFT JOIN tblemployee a on concat(a.fName,' ',a.midInit,'.',' ',a.lName) = z.transby
	left join tblempauth b on b.idEmp = a.idEmp
set z.transby = b.userName
where z.transby !='system';
DROP TABLE IF EXISTS TEMP2;
CREATE TEMPORARY TABLE TEMP2 (
	id int NOT NULL AUTO_INCREMENT,
	transdate Date,
	transid int,
	transNo varchar(20),
	transdesc varchar(20),
	code INT,
	qtybeg int,
	qtyin int,
	qtyout int,
	qtyend int,
	amount double(18,2),
	cost double(18,2),
	srp double(18,2),
	unit varchar(10),
	idcategory int,
	idbrand int,
	idSupplier int,
	remarks varchar(100),
	status varchar(50),
	partnum varchar(50),
	transby varchar(50),
	itemName varchar(100),
   PRIMARY KEY (`id`)
	)  ENGINE=InnoDB AUTO_INCREMENT=2378 DEFAULT CHARSET=utf8;
INSERT INTO TEMP2(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partNum,transby,itemName) 
SELECT transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partnum,transby,itemName 
FROM TEMP ORDER BY transdate;
UPDATE TEMP2 a set a.unit = (Select b.unit from tblunit b where a.unit = b.idUnit);
TRUNCATE TABLE TEMP;
BEGIN
DECLARE cur CURSOR FOR SELECT distinct CODE FROM TEMP2;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
set endingx = 0;
OPEN cur;
 SET done = 0;
   read_loop: LOOP
	    FETCH cur INTO codex;
	    IF done THEN
	    	LEAVE read_loop;
	    END IF;
		 	BEGIN
			DECLARE cur2 CURSOR FOR SELECT id FROM TEMP2 where code = codex order by id;
			DECLARE CONTINUE HANDLER FOR NOT FOUND SET done2 = 1;
			set minx = (select min(id) from TEMP2 WHERE code = codex);
			set endingx = (select qtyend from TEMP2 WHERE id = minx and code = codex );
						OPEN cur2;
			 SET done2 = 0;
			   read_loop2: LOOP
				    FETCH cur2 INTO idex;
				    IF done2 THEN
				    	LEAVE read_loop2;
				    END IF;
				    		    		 	 UPDATE TEMP2 SET qtybeg = endingx
						 WHERE code = codex and id=idex;
						 UPDATE TEMP2 SET qtyend = (qtybeg + qtyin - qtyout)
						 WHERE code = codex and id=idex;
						 set endingx = (select qtyend FROM TEMP2 WHERE id=idex and code = codex);
			   END LOOP;
			CLOSE cur2;
			END;
				 INSERT INTO TEMP(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partnum,transby,itemName)
	 SELECT transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partnum,transby,itemName
	 FROM TEMP2 WHERE code = codex;
	 	END LOOP;
	 	CLOSE cur;
END;
if paramcode = '' or paramcode = 'all' then
	TRUNCATE TABLE tblitemhistory;
	INSERT INTO tblitemhistory(transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partNum,transby,itemName) 
	select transDate, transID, transNo,transDesc,code,qtyBeg,qtyIn,qtyOut,qtyEnd,amount,cost,srp,unit,idCategory,idBrand,idSupplier,remarks,status, partNum,ifnull(transby,''),itemName
	from TEMP 
	WHERE (qtyBeg + qtyIn + qtyOut + qtyEnd) <> 0
	ORDER BY transdate;
		SELECT 'tblitemhistory updated!' as Message;
		else
	if paramethod = '' then
	
	select
	id,
	DATE_FORMAT(transdate,'%Y-%m-%d') as transdate,
	transid,
	transNo,
	transdesc,
	code ,
	qtybeg,
	qtyin,
	qtyout,
	qtyend,
	amount,
	cost,
	srp,
	unit,
	idcategory,
	idbrand,
	idSupplier,
	remarks,
	status,
	partNum,
	ifnull(transby,'') as transby,
	itemName
	FROM TEMP2;
	end if;
end if;
END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_invmasterlist
DROP PROCEDURE IF EXISTS `sp_invmasterlist`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_invmasterlist`(IN `date_start` daTE, IN `date_end` daTE)
BEGIN
/* UPDATED 12.4.2015 BY MCA
====================================================
REMARKS: added SRP, Cost & itemname
====================================================
*/
DECLARE vMinid int;
DECLARE vMaxid int;
DECLARE vCode int;
DECLARE vSumIn double(18,2);
DECLARE vSumOut double(18,2);
DECLARE done INT;
DECLARE cntresult INT;
DROP TABLE IF EXISTS TEMP;

CREATE TEMPORARY TABLE TEMP (
	id int,
	transdate Date,
	transid int,
	transNo varchar(20),
	transdesc varchar(20),
	code INT,
	itemName varchar(100),
	qtybeg int,
	qtyin int,
	qtyout int,
	qtyend int,
	amount double(18,2),
	cost double(18,2),
	srp double(18,2),
	unit varchar(10),
	idcategory int,
	idbrand int,
	idSupplier int,
	remarks varchar(100),
	idbeg int,
	idend int,
	status varchar(50)
  	);

	BEGIN
		DECLARE cur CURSOR FOR select code from tblitemhistory
		where (qtybeg+qtyin+qtyout+qtyend) <> 0 group by code;-- where code = options;
		-- where qtybeg <> 0 and qtyend <> 0 and qtyin <> 0 and qtyout <> 0 group by code;
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
			OPEN cur;
			 SET done = 0;
			   read_loop: LOOP
				    FETCH cur INTO vCode;
				    IF done THEN
				    	LEAVE read_loop;
				    END IF;

				set cntresult = (select count(idhistory) from tblitemhistory 
				where transdate >= date_start and transdate<=date_end and code = vCode);	

					if cntresult = 0 then
						set vMinid = (select max(idHistory) from tblitemhistory where 
							transdate < date_start and code = vCode);
				set vMaxid = (select max(idHistory) from tblitemhistory where 
					transdate < date_end and code = vCode);
				set vSumIn = (select qtyIn from tblitemhistory where idhistory = 
					vMinid);
				set vSumOut = (select qtyOut from tblitemhistory where idhistory = 
					vMinid);

			else		
				set vMinid = (select min(idhistory) from tblitemhistory where 
					transdate >= date_start and transdate<=date_end and code = vCode group by code);
				set vMaxid = (select max(idhistory) from tblitemhistory where 
					transdate >= date_start and transdate<=date_end and code = vCode group by code);
				set vSumIn = (select sum(qtyIn) from tblitemhistory where transdate 
					>= date_start and transdate<=date_end and code = vCode group by code);
				set vSumOut = (select sum(qtyOut) from tblitemhistory where 
					transdate >= date_start and transdate<=date_end and code = vCode group by code);

			end if;

		INSERT INTO TEMP(id, code,itemName, cost, srp, unit, idcategory, idbrand, idsupplier, idbeg, qtyIn, 
			qtyOut, idend) 
		SELECT vMaxid, code,itemName,cost, srp, unit, idcategory, idbrand, idsupplier, vMinid, vSumIn, vSumOut, 
		vMaxid from tblitemhistory
		WHERE  code = vCode and idhistory = vMaxid;

		-- UPDATE TEMP SET idend = vMaxid where code = vCode;

		UPDATE TEMP a left join tblitemhistory b on a.idend = b.idhistory
		SET a.transdate = b.transDate, a.transid = b.transID, a.transno = b.transNo, 
		a.transdesc = b.transdesc, a.qtyend = b.qtyEnd, a.amount = b.amount
		WHERE a.code = vCode and b.idhistory = vMaxid;

		UPDATE TEMP a left join tblitemhistory b on a.idbeg = b.idhistory
		SET a.qtybeg = b.qtybeg
		WHERE a.code = vCode and b.idhistory = vMinid;

	END LOOP;
	CLOSE cur;
END;
	select * from TEMP where id is not null and (qtybeg+qtyin+qtyout+qtyend) <> 0;
	END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_itempricelist
DROP PROCEDURE IF EXISTS `sp_itempricelist`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_itempricelist`(IN `paramOption` VARCHAR(50), IN `paramCat` VARCHAR(200), IN `paramBrand` VARCHAR(200), IN `paramFilter` VARCHAR(200))
BEGIN

/*
=========================================
UPDATED BY: Annie Rose M. Deloso 12082015
=========================================
*/

DECLARE strsql varchar(1500);
DECLARE whereFilter varchar(1500);
DECLARE qtyJE int;
DECLARE qtySales int;

DROP TEMPORARY TABLE IF EXISTS TEMP;

CREATE TEMPORARY TABLE TEMP

(
	idItem int,
	code int,
	partNo varchar(100),
	itemName varchar(200),
   details varchar(1000),
   qtyBeg int,
   qtyIn int,
   qtyOut int,
   qtyIssued int,
   qtyBal int,
   qtyAvbl int,
   srp double(12,2),
   cost double(12,2),
   unit varchar(25),
   category varchar(100),
   brand varchar(100),
   itemStatus varchar(50),
   bikeComp varchar(200),
   itemBin varchar(100)
);

 set @strsql = 'INSERT INTO TEMP(idItem, code, partNo, itemName, details, qtyBeg, qtyIn, qtyOut, qtyIssued, qtyBal, qtyAvbl,  
      		 srp, cost, unit, category, brand, itemStatus, bikeComp,  itemBin) 
			 SELECT IFNULL(i.idItem, 0), IFNULL(i.code, 0), IFNULL(i.partNum, ""), IFNULL(i.itemName, "_"), IFNULL(i.detail, "_"), 
			 IFNULL(inv.qtyBeg, 0), IFNULL(inv.qtyIn, 0), IFNULL(inv.qtyOut, 0), 0, IFNULL(inv.qtyEnd, 0), 0,
			 IFNULL(inv.srp, 0), IFNULL(inv.cost, 0), IFNULL(u.Unit, ""), IFNULL(ic.Category, "_"),
			 IFNULL(ib.brandName, "_"), IFNULL(i.itemStatus, "_"), IFNULL(i.bikeModel, "_"), 
			 IFNULL(i.vin, "_")    
			 FROM tblinventory inv
			 LEFT JOIN tblitem i ON i.code=inv.code
			 LEFT JOIN tblitemcategory ic ON ic.idCategory=i.idCategory
			 LEFT JOIN tblitembrand ib ON ib.idBrand=i.idBrand
			 LEFT JOIN tblunit u ON u.idUnit=i.idUnit';

set @whereBrand= paramBrand;			 
set @whereCat = paramCat;
set @whereParamFilter= CONCAT("%", paramFilter, "%");
set @whereParamCode= paramFilter;

	     	
IF paramOption='byItem' THEN
   
   IF paramBrand <> 'All'  AND paramCat <> 'All' THEN
   
   	 IF paramFilter='' OR paramFilter='All' THEN
   		set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereBrand; 
			
   	 ELSE
   	 	set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ? AND i.itemName LIKE ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereBrand, @whereParamFilter; 
			
   	 END IF;
   	 
	ELSEIF paramBrand = 'All'  AND paramCat <> 'All' THEN
	
		 IF paramFilter='' OR paramFilter='All' THEN
		 
   		set whereFilter = ' WHERE ic.Category = ?';
   		
			set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat; 
			
   	 ELSE
   	 
   	 	set whereFilter = ' WHERE ic.Category = ? AND i.itemName LIKE ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereParamFilter; 
			
   	 END IF;	
   	 
	ELSEIF paramBrand <> 'All'  AND paramCat = 'All' THEN
	
		 IF paramFilter='' OR paramFilter='All' THEN
		 
   		set whereFilter = ' WHERE ib.brandName = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING  @whereBrand; 
			
   	 ELSE
   	 
   	 	set whereFilter = ' WHERE ib.brandName = ? AND i.itemName LIKE ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereBrand, @whereParamFilter; 
			
   	 END IF;	 
		 
	ELSE
	
		 IF paramFilter='' OR paramFilter='All' THEN

		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1; 
			
   	 ELSE
   	 
   	 	set whereFilter = ' WHERE i.itemName LIKE ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereParamFilter; 
			
   	 END IF;	 
		 	
	END IF;
			
  		
ELSEIF  paramOption='byCode' THEN
		 
    IF paramBrand <> 'All'  AND paramCat <> 'All' THEN
   
   	 IF paramFilter='' OR paramFilter='All' THEN
   	 
	   	 set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ?';
	   		
	   	 set @strsql = CONCAT(@strsql, whereFilter);	
			 PREPARE stmt1 FROM @strsql;
			 EXECUTE stmt1 USING @whereCat, @whereBrand; 
			
   	 ELSE
	 
   	 	set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ? AND inv.code = ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereBrand, @whereParamCode; 
			
   	 END IF;
   	 
	 ELSEIF paramBrand = 'All'  AND paramCat <> 'All' THEN
	
		 IF paramFilter='' OR paramFilter='All' THEN
			 
	   	set whereFilter = ' WHERE ic.Category = ?';
	   		
			set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat; 
				
	    ELSE
	   	 
	   	set whereFilter = ' WHERE ic.Category = ? AND inv.code = ?';
	   	 	
	   	set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereParamCode; 
				
	    END IF;	
   	 
	 ELSEIF paramBrand <> 'All'  AND paramCat = 'All' THEN
	
	    IF paramFilter='' OR paramFilter='All' THEN
		 
   		set whereFilter = ' WHERE ib.brandName = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
		   EXECUTE stmt1 USING  @whereBrand; 
			
   	 ELSE
   	 
   	 	set whereFilter = ' WHERE ib.brandName = ? AND inv.code = ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
		   EXECUTE stmt1 USING @whereBrand, @whereParamCode; 
			
   	 END IF;	 
		 
    ELSE
	
	   IF paramFilter='' OR paramFilter='All' THEN

		   PREPARE stmt1 FROM @strsql;
	   	EXECUTE stmt1; 
	   		
   	ELSE
   	 
   	 	set whereFilter = ' WHERE inv.code = ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
		   PREPARE stmt1 FROM @strsql;
		   EXECUTE stmt1 USING @whereParamCode; 
			
   	END IF;	 
		 	
    END IF;

ELSEIF  paramOption='byPartNo' THEN
		 
	 IF paramBrand <> 'All'  AND paramCat <> 'All' THEN
   
   	 IF paramFilter='' OR paramFilter='All' THEN
   	 
   		set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereBrand; 
			
   	 ELSE
	 
   	 	set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ? AND i.partNum LIKE ?';
   	 	
   	 	set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereBrand, @whereParamFilter; 
			
   	 END IF;
   	 
	 ELSEIF paramBrand = 'All'  AND paramCat <> 'All' THEN
	
		 IF paramFilter='' OR paramFilter='All' THEN
		 
   	 	set whereFilter = ' WHERE ic.Category = ?';
   		
			set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat; 
			
   	 ELSE
   	 
   		set whereFilter = ' WHERE ic.Category = ? AND i.partNum LIKE ?';
   	 	
   		set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereParamFilter; 
			
   	END IF;	
   	 
	 ELSEIF paramBrand <> 'All'  AND paramCat = 'All' THEN
	
	 	IF paramFilter='' OR paramFilter='All' THEN
		 
   	 	set whereFilter = ' WHERE ib.brandName = ?';
   		
	   	set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING  @whereBrand; 
			
      ELSE
   	 
   	   set whereFilter = ' WHERE ib.brandName = ? AND i.partNum LIKE ?';
   	 	
   	   set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
		   EXECUTE stmt1 USING @whereBrand, @whereParamFilter; 
			
     END IF;	 
		 
   ELSE
	
	 IF paramFilter='' OR paramFilter='All' THEN

		PREPARE stmt1 FROM @strsql;
		EXECUTE stmt1; 
			
    ELSE
   	 
   	set whereFilter = ' WHERE i.partNum LIKE ?';
   	 	
   	set @strsql = CONCAT(@strsql, whereFilter);	
		PREPARE stmt1 FROM @strsql;
		EXECUTE stmt1 USING @whereParamFilter; 
			
    END IF;	 
		 	
  END IF;

ELSE

  IF paramBrand <> 'All'  AND paramCat <> 'All' THEN
   
   	 IF paramFilter='' OR paramFilter='All' THEN
   	 
   		set whereFilter = ' WHERE ic.Category = ? AND ib.brandName = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat, @whereBrand; 
					
   	 END IF;
   
	ELSEIF paramBrand = 'All'  AND paramCat <> 'All' THEN
		
		 IF paramFilter='' OR paramFilter='All' THEN
   	 
   		set whereFilter = ' WHERE ic.Category = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereCat; 
					
   	 END IF;
   	 
   ELSEIF paramBrand <> 'All'  AND paramCat = 'All' THEN
		
		 IF paramFilter='' OR paramFilter='All' THEN
   	 
   		set whereFilter = ' WHERE ib.brandName = ?';
   		
   		set @strsql = CONCAT(@strsql, whereFilter);	
			PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1 USING @whereBrand; 
					
   	 END IF; 	 
  
  	ELSEIF paramBrand = 'All'  AND paramCat = 'All' THEN
		
		 IF paramFilter='' OR paramFilter='All' THEN
   	 
   		PREPARE stmt1 FROM @strsql;
			EXECUTE stmt1; 
					
   	 END IF; 	 
		 
	END IF;	 	

						 	 		
END IF; -- End of Main Nested If Else
		  	 						
DEALLOCATE PREPARE stmt1;

 -- UPDATE TEMP with issued qtys
 
  UPDATE TEMP t SET t.qtyIssued = (SELECT IFNULL(SUM(j.qty), 0) FROM tbljoitems j WHERE j.status='Issued' AND j.idItem = t.code);
  UPDATE TEMP t SET t.qtyIssued = (t.qtyIssued + IFNULL((SELECT ts.qty FROM tbltmpsales ts WHERE ts.idItem = t.code), 0));
  UPDATE TEMP SET qtyAvbl = (IFNULL(qtyBal, 0) - IFNULL(qtyIssued, 0)); 
  
SELECT * FROM TEMP;
-- SELECT @strsql;
END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_JEreport
DROP PROCEDURE IF EXISTS `sp_JEreport`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_JEreport`(IN `paramsid` VARCHAR(50), IN `options` varCHAR(50))
BEGIN







DROP TEMPORARY TABLE IF EXISTS TEMP;



CREATE TEMPORARY TABLE TEMP



(



	id varchar(20),



	itemname varchar(250),



	code varchar(50),



	qty varchar(10),



	unit varchar(10),



	unitprice double(18,2),

	

	discount int,



	amount double (18,2),



	category varchar(50),



	sortkey int		



);







if options = "JE" then



	INSERT INTO TEMP



	select a.jeid, c.itemName, 



		(case 



			when c.partnum is null then b.iditem



			when c.partNum = "0" then b.iditem



			when c.partnum = "" then b.iditem



		else 



			concat(b.iditem," / ",c.partNum)



		end) as code,



		b.qty, b.unit, b.unitPrice, b.discount, (b.qty * b.unitPrice), 'ITEMS', 1



		from tbljoborder a



	left join tbljoitems b on b.idJO = a.idJO



	left join tblitem c on c.code = b.idItem



	where jeid = paramsid;







	INSERT INTO TEMP



	select a.jeid, upper(b.services), '',



		if(b.minutes=0,'-',round(b.minutes/60,2)),



		IF(b.minutes=0,'-','Hr(s)'),



		if(b.minutes=0, 0,a.flatRate), ((a.srvcDscnt / a.grandTotal) *100),



		if(b.minutes>0,((b.minutes / 60) * a.flatRate),b.charge),



		'SERVICE LABOR & MATERIALS', 2 



		from tbljoborder a



	left join tbljoservices b on b.idJO = a.idJO



	where a.jeid = paramsid;







elseif options = "JO" then



	INSERT INTO TEMP



	select a.joid, c.itemName, 



		(case 



			when c.partnum is null then b.iditem



			when c.partNum = "0" then b.iditem



			when c.partnum = "" then b.iditem



		else 



			concat(b.iditem," / ",c.partNum)



		end) as code,



		b.qty, b.unit, b.unitPrice, b.discount, (b.qty * b.unitPrice), 'ITEMS', 1



		from tbljoborder a



	left join tbljoitems b on b.idJO = a.idJO



	left join tblitem c on c.code = b.idItem



	where a.joid = paramsid;







	INSERT INTO TEMP



	select a.joid, b.services, '',



		IF(b.minutes=0,0,round(b.minutes/60,2)),



		IF(b.minutes=0,'','Hr(s)'),



		IF(b.minutes=0, 0,a.flatRate), ((a.srvcDscnt / a.grandTotal) *100),



		IF(b.minutes>0,((b.minutes / 60) * a.flatRate),b.charge),



		'SERVICE LABOR & MATERIALS', 2 



		from tbljoborder a



	left join tbljoservices b on b.idJO = a.idJO



	where a.joid = paramsid;







end if;







DELETE FROM TEMP WHERE itemname is null and code is null;



select * from TEMP order by sortkey;







END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_sales
DROP PROCEDURE IF EXISTS `sp_sales`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_sales`(IN `date_start` VARCHAR(50), IN `date_end` VARCHAR(50), IN `options` VARCHAR(50))
BEGIN
/* UPDATED 11.9.2015 BY MCA
====================================================
REMARKS: Change Payment Remarks(concat payment mode and payment type)
			Change Summary 
			- CASH
			- CREDIT CARD
			- AR
			- FREEBIES
			- WARRANTY
			- MARKETING EXPENSE
			- OPERATING EXPENSE
====================================================
*/
DECLARE done INT;
DECLARE catid varchar(50);
DECLARE cmd varchar(1000);
DECLARE output_tax double(10,2);
DECLARE net_vat double(10,2);
DECLARE vatdiv float;
DECLARE taxdiv float;
DECLARE sum_qty int;
DROP TEMPORARY TABLE IF EXISTS TEMP;

CREATE TEMPORARY TABLE TEMP (
	dateSO Date,
	soID VARCHAR(15),
	itemname VARCHAR(250),
	qty varchar(20),
	unit VARCHAR(10),
	unitPrice double(10,2),
	discount double(10,2),
	amount double(18,2),
	netvat double(18,2),
	outputtax double(18,2),
	category varchar(250),
	remarks varchar(1000),
	brand varchar(250),
	suppliercode varchar(10),
	supplier varchar(150),
	sortkey int
);
SET vatdiv = 1/1.12;
SET taxdiv = 12/100;
PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateSO, 
		(
		case 
			when a.soID="0" then 
			case 
				when b.salesInvc = "0" then b.salesOR
			else
				b.salesInvc
			end
		else
			a.soID
		end
		), c.Itemname, a.qty, e.Unit, a.unitPrice, (a.amount*(a.discount/100)), 
		a.amount,(amount * (1/1.12)) , 
		((amount * (1/1.12))* (12/100)), 
		d.Category, concat(b.payMode," - ",b.type), UPPER(f.brandname), g.code, UPPER(g.suppliername), 1 
		from tblsales a
left join tblsalesorder b on a.id=b.id
left join tblitem c on a.idItem=c.code
left join tblitemcategory d on d.idCategory = c.idcategory
left join tblunit e on e.idUnit=c.idUnit
left join tblitembrand f on f.idbrand = c.idbrand
left join tblsupplier g on g.idsupplier = c.idsupplier
where b.dateSO between ? and ?
order by d.category, b.dateSO, a.soID';
set @start = date_start;
set @end = date_end;
EXECUTE stmt1 USING @start, @end;
DEALLOCATE PREPARE stmt1;
PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateRsrv, a.rsrvNo, UPPER(a.itemname), a.qty, a.unit, 
a.amount, 0,a.amount, 
		(a.amount * (1/1.12)) , ((a.amount * (1/1.12))* (12/100)), 
		"Acknowledgement Receipt", concat(b.payMode," - ",b.type), "CASH COLLECTIONS","AR", "CASH COLLECTIONS", 5
		from tblreserveitems a
left join tblreserveorder b on a.rsrvNo=b.rsrvNo 
left join tblitem c on c.iditem=a.iditem
left join tblitembrand d on d.idbrand=c.idbrand
left join tblsupplier e on e.idSupplier = c.idSupplier
where b.dateRsrv between ? and ?
order by b.dateRsrv, b.rsrvNo';
set @start = date_start;
set @end = date_end;
EXECUTE stmt1 USING @start, @end;
DEALLOCATE PREPARE stmt1;
PREPARE stmt1 FROM 'INSERT INTO TEMP select c.dateSO, a.jeid, UPPER(concat(b.lName,", ", b.fName," ", if(b.midInit="","",concat(b.midInit,".")))), ROUND((a.minutes/60),2), if((a.minutes/60)="0", "","hr(s)"),
		if(a.minutes=0,0,a.flatRate),(a.srvcDscnt + a.partDscnt),
		(a.srvcTotal-a.srvcDscnt), ((a.srvcTotal-a.srvcDscnt)*(1/1.12)),((a.srvcTotal-a.srvcDscnt)*(1/1.12)*(12/100)), 
		"Service Labor & Materials", concat(c.payMode," - ",c.type), "SERVICE LABOR", "SVC","SERVICE",4 
		from tbljoborder a
left join tblcustomer b on b.idcustomer = a.idCustomer
left join tblsalesorder c on a.jeid = c.jeid
where (a.status ="sold" OR a.status ="completed") and (c.dateSO between ? and ?)
order by c.dateSO, a.jeid';
Set @start = date_start;
set @end = date_end;
EXECUTE stmt1 USING @start, @end;
DEALLOCATE PREPARE stmt1;
UPDATE TEMP SET SORTKEY = 3, brand='CONSIGNED ITEMS', supplier ='CONSIGNED ITEMS' 
WHERE category LIKE '%consign%';
UPDATE TEMP SET unit ="-", unitPrice=amount where qty =0;
if options = 'summary' then
	BEGIN
	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;
	CREATE TEMPORARY TABLE TEMPSUM (
		category varchar(50),
		quantity varchar(20),
		cash double(18,2),
		AR double(18,2),
		credit double(18,2),
		freebies double(18,2),
		warranty double(18,2),
		marketingexp double(18,2),
		operatingexp double(18,2),
		amount double(18,2),
		sortkey int
	);
	INSERT INTO TEMPSUM(category,amount,quantity, sortkey) 
		SELECT category, sum(amount),sum(qty),sortkey from TEMP GROUP BY category, sortkey;
		
	UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks like 
				'Cash -%' or b.remarks like 'Check (OnDate)%' or b.remarks like 'Debit%' or b.remarks like 'Others - Cash%') and b.category =a.category);
				
	UPDATE TEMPSUM a SET a.credit = (select sum(b.amount) from TEMP b where b.remarks like 
		'Credit Card -%' and b.category = a.category);
		
	UPDATE TEMPSUM a SET a.AR = (select sum(b.amount) from TEMP b where (b.remarks like 
		'%Check (PDC)%' or b.remarks like 'Others - AR%') and b.category = a.category);

	UPDATE TEMPSUM a SET a.freebies = (select sum(b.amount) from TEMP b where b.remarks like 
		'%freebies%' and b.category = a.category);

	UPDATE TEMPSUM a SET a.marketingexp = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Marketing Expense%' and b.category = a.category);

	UPDATE TEMPSUM a SET a.operatingexp = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Operating Expense%' and b.category = a.category);

	UPDATE TEMPSUM a SET a.warranty = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Warranty%' and b.category = a.category);
			
	SELECT * FROM TEMPSUM ORDER BY SORTKEY, category;
	END;
	
elseif options = 'brand' then
	BEGIN
	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;
	CREATE TEMPORARY TABLE TEMPSUM (
		brand varchar(50),
		quantity varchar(20),
		cash double(18,2),
		AR double(18,2),
		credit double(18,2),
		freebies double(18,2),
		warranty double(18,2),
		marketingexp double(18,2),
		operatingexp double(18,2),
		amount double(18,2),
		sortkey int
	);
	INSERT INTO TEMPSUM(brand,amount,quantity, sortkey) 
		SELECT brand, sum(amount),sum(qty),sortkey from TEMP GROUP BY brand, sortkey;
		
	UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks like 
				'Cash -%' or b.remarks like 'Check (OnDate)%' or b.remarks like 'Debit%' or b.remarks like 'Others - Cash%') and b.brand =a.brand);
				
	UPDATE TEMPSUM a SET a.credit = (select sum(b.amount) from TEMP b where b.remarks like 
		'Credit Card -%' and b.brand = a.brand);
		
	UPDATE TEMPSUM a SET a.AR = (select sum(b.amount) from TEMP b where (b.remarks like 
		'%Check (PDC)%' or b.remarks like 'Others - AR%') and b.brand = a.brand);

	UPDATE TEMPSUM a SET a.freebies = (select sum(b.amount) from TEMP b where b.remarks like 
		'%freebies%' and b.brand = a.brand);

	UPDATE TEMPSUM a SET a.marketingexp = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Marketing Expense%' and b.brand = a.brand);

	UPDATE TEMPSUM a SET a.operatingexp = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Operating Expense%' and b.brand = a.brand);

	UPDATE TEMPSUM a SET a.warranty = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Warranty%' and b.brand = a.brand);
			
	SELECT * FROM TEMPSUM ORDER BY SORTKEY, brand;
	END;
	elseif options = 'supplier' then
	BEGIN
	DROP TEMPORARY TABLE IF EXISTS TEMPSUM;
	CREATE TEMPORARY TABLE TEMPSUM (
		supplier varchar(50),
		quantity varchar(20),
		cash double(18,2),
		AR double(18,2),
		credit double(18,2),
		freebies double(18,2),
		warranty double(18,2),
		marketingexp double(18,2),
		operatingexp double(18,2),
		amount double(18,2),
		sortkey int
	);
	INSERT INTO TEMPSUM(supplier,amount,quantity, sortkey) 
		SELECT supplier, sum(amount),sum(qty),sortkey from TEMP GROUP BY supplier, sortkey;
		
	UPDATE TEMPSUM a SET a.cash = (select sum(b.amount) from TEMP b where (b.remarks like 
				'Cash -%' or b.remarks like 'Check (OnDate)%' or b.remarks like 'Debit%' or b.remarks like 'Others - Cash%') and b.supplier =a.supplier);
				
	UPDATE TEMPSUM a SET a.credit = (select sum(b.amount) from TEMP b where b.remarks like 
		'Credit Card -%' and b.supplier = a.supplier);
		
	UPDATE TEMPSUM a SET a.AR = (select sum(b.amount) from TEMP b where (b.remarks like 
		'%Check (PDC)%' or b.remarks like 'Others - AR%') and b.supplier = a.supplier);

	UPDATE TEMPSUM a SET a.freebies = (select sum(b.amount) from TEMP b where b.remarks like 
		'%freebies%' and b.supplier = a.supplier);

	UPDATE TEMPSUM a SET a.marketingexp = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Marketing Expense%' and b.supplier = a.supplier);

	UPDATE TEMPSUM a SET a.operatingexp = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Operating Expense%' and b.supplier = a.supplier);

	UPDATE TEMPSUM a SET a.warranty = (select sum(b.amount) from TEMP b where b.remarks like 
		'%Warranty%' and b.supplier = a.supplier);
			
	SELECT * FROM TEMPSUM ORDER BY SORTKEY, supplier;
	END;
	else
		if options = 'bySupplier'	then
			SELECT * FROM TEMP order by sortkey, supplier,dateSO, SOid;
		elseif options ='byBrand' then
			SELECT * FROM TEMP order by sortkey, brand, dateSO, SOid;
		elseif options ='byCategory' then
			SELECT * FROM TEMP order by sortkey, category, dateSO, SOid;
		else
			SELECT * FROM TEMP order by sortkey, dateSO, SOid;
		end if;
	end if;
END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_salesreport
DROP PROCEDURE IF EXISTS `sp_salesreport`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_salesreport`(IN `date_start` VARCHAR(50), IN `date_end` VARCHAR(50), IN `accountuser` varCHAR(50))
BEGIN































DECLARE done INT;















DECLARE catid varchar(50);















DECLARE cmd varchar(1000);















DECLARE output_tax double(10,2);















DECLARE net_vat double(10,2);















DECLARE vatdiv float;















DECLARE taxdiv float;















DECLARE sum_qty int;















DROP TABLE IF EXISTS TEMP;















CREATE TEMPORARY TABLE TEMP (















	dateSO Date,















	soID VARCHAR(15),















	itemname VARCHAR(100),















	qty int,















	unit VARCHAR(10),















	unitPrice double(10,2),















	discount int,















	amount double(18,2),















	category varchar(50),















	remarks varchar(100),















	sortkey int















);































PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateSO, 















	(















		case 















			when a.soID=0 then 















			case 















				when b.salesInvc = 0 then b.salesOR















			else















				b.salesInvc















			end















		else















			a.soID















		end















		), 















	c.Itemname, a.qty, e.Unit, a.unitPrice, a.discount, (a.amount-(a.amount*(discount/100))), 







d.Category, b.remarks, 1 















from tblsales a















left join tblsalesorder b on a.id=b.id















left join tblitem c on a.idItem=c.code















left join tblitemcategory d on d.idCategory = c.idcategory















left join tblunit e on e.idUnit=c.idUnit















where b.dateSO between ? and ?















order by d.category, b.dateSO, a.soID';















set @start = date_start;















set @end = date_end;















EXECUTE stmt1 USING @start, @end;















DEALLOCATE PREPARE stmt1;































PREPARE stmt1 FROM 'INSERT INTO TEMP select b.dateRsrv, a.rsrvNo, a.itemname, a.qty, a.unit, 







a.unitprice, null,amount, "Acknowledgement Receipt", b.remarks, 3















from tblreserveitems a















left join tblreserveorder b on a.rsrvNo=b.rsrvNo where b.dateRsrv between ? and ?















order by b.dateRsrv, b.rsrvNo';















set @start = date_start;















set @end = date_end;















EXECUTE stmt1 USING @start, @end;















DEALLOCATE PREPARE stmt1;































PREPARE stmt1 FROM 'INSERT INTO TEMP select a.dateFinished, a.jeid, upper(concat(b.lname,", 







",b.fname, 















(case 















	when b.midInit= "" then "" 















	else 















	concat(" ", b.midinit,".") 















end))), a.minutes, "Min(s)", a.flatRate, null,((a.minutes/60)*a.flatRate), "Service Labor & 







Materials", a.paymode, 4 















from tbljoborder a left join tblcustomer b on a.idCustomer = b.idCustomer















where a.dateFinished between ? and ? and status ="done"















order by a.dateFinished, a.jeid';















set @start = date_start;















set @end = date_end;















EXECUTE stmt1 USING @start, @end;















DEALLOCATE PREPARE stmt1;































UPDATE TEMP SET SORTKEY = 2 WHERE CATEGORY LIKE '%consign%';































BEGIN















DECLARE cur CURSOR FOR SELECT distinct category FROM TEMP ORDER BY SORTKEY, category;















DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;















DROP TEMPORARY TABLE IF EXISTS TEMP2;















  CREATE TEMPORARY TABLE IF NOT EXISTS TEMP2  (















   dateSO Varchar(50),















	soID VARCHAR(50),















	itemname VARCHAR(100),















	dummy varchar(100),















	qty int,















	unit VARCHAR(50),















	unitPrice double(18,2),















	discount int,















	amount double(18,2),















	netvat double(18,2),















	tax double(18,2),















	remarks varchar(100),















	pk int















	















  );















-- for recap  















DROP TEMPORARY TABLE IF EXISTS TEMP3;















CREATE TEMPORARY TABLE TEMP3 (















	category varchar(50),















	amount double(18,2),















	quantity int,















	paymentmode varchar(50),















	suser varchar(50),















	pkey int















);































SET vatdiv = 1/1.12;















SET taxdiv = 12/100;















OPEN cur;















 SET done = 0;















   read_loop: LOOP















	    FETCH cur INTO catid;















	    IF done THEN















	    	LEAVE read_loop;















	    END IF;































       INSERT INTO TEMP2(dateSO, pk) SELECT catid, 1;















       INSERT INTO TEMP2 SELECT CONCAT('    ',dateSO), soID, itemname, null, qty, unit, unitPrice, 







discount, amount, (amount * vatdiv), ((amount * vatdiv)* taxdiv),remarks, null















		 from TEMP WHERE category=catid;















		 if catid like '%service%' then















		 	INSERT INTO TEMP2 select null,null, 'SUBTOTAL', null,count(qty), null, 







null,NULL, sum(amount), sum(amount * vatdiv), sum((amount * vatdiv)* taxdiv),null,2















		 	from TEMP WHERE category=catid;















		 	INSERT INTO TEMP3 SELECT catid, sum(amount), count(qty),'Cash',null,5 from 







TEMP WHERE category=catid and remarks not like '%charge%';















		 	INSERT INTO TEMP3 SELECT catid, sum(amount), count(qty),'Charge',null,5 from 







TEMP WHERE category=catid and remarks like '%charge%';	 	 















		 else















		   INSERT INTO TEMP2 select null,null, 'SUBTOTAL', null,sum(qty), null, null,NULL, 







sum(amount), sum(amount * vatdiv), sum((amount * vatdiv)* taxdiv),null,2















		   from TEMP WHERE category=catid;















		   INSERT INTO TEMP3 SELECT catid, sum(amount), sum(qty),'Cash',null,5 from TEMP 







WHERE category=catid and remarks not like '%charge%' and remarks not like '%advertising%';















		 	INSERT INTO TEMP3 SELECT catid, sum(amount), sum(qty),'Charge',null,5 from 







TEMP WHERE category=catid and remarks like '%charge%';	 	 















		 	INSERT INTO TEMP3 SELECT catid, sum(amount), sum(qty),'Advertising',null,5 







from TEMP WHERE category=catid and remarks like '%advertising%';















		 end if;















		 	 	 	 	  	 















	END LOOP;















CLOSE cur;















END;































INSERT INTO TEMP2(dateSO) select null;















SET sum_qty = (SELECT sum(qty) from TEMP2 where itemname ='SUBTOTAL');















INSERT INTO TEMP2 select null,null, 'GRAND TOTAL',null, sum_qty, null, null, NULL, sum(amount), sum







(amount * vatdiv), sum(amount * taxdiv),null,3















from TEMP;































INSERT INTO TEMP2(dateSO) select null;































DROP TEMPORARY TABLE IF EXISTS TEMP4;















CREATE TEMPORARY TABLE TEMP4 (















	category varchar(50),















	amount double(18,2),















	quantity int,















	cash double(18,2),















	charge double(18,2),















	advertising double(18,2),















	suser varchar(50),















	pkey int,















	sortkey int















);















INSERT INTO TEMP2(dateSO,dummy,pk) SELECT 'Prepared by:', 'SUMMARY', 4;















INSERT INTO TEMP4(category, amount, quantity, pkey) SELECT category, sum(amount),sum(quantity), pkey 







from TEMP3 group by category;































UPDATE TEMP4 a















set a.cash =(SELECT SUM(b.amount) FROM TEMP3 b where b.paymentmode = 'Cash' and 







b.category=a.category);































UPDATE TEMP4 a















set a.charge =(SELECT SUM(b.amount) FROM TEMP3 b where b.paymentmode = 'Charge' and 







b.category=a.category);































UPDATE TEMP4 a















set a.advertising =(SELECT SUM(b.amount) FROM TEMP3 b where b.paymentmode = 'Advertising' and 







b.category=a.category);































UPDATE TEMP4 SET sortkey = (















CASE















	WHEN category ="Consigned Items" then '2'















	WHEN category ="Acknowledgement Receipt" then '3'















	WHEN category ="Service Labor & Materials" then '3'















ELSE















	'1'















END















);















DROP TEMPORARY TABLE IF EXISTS TEMP3;















CREATE TEMPORARY TABLE TEMP3 (















	category varchar(50),















	amount double(18,2),















	quantity int,















	cash double(18,2),















	charge double(18,2),















	advertising double(18,2),















	suser varchar(50),















	pkey int,















	sortkey int















);































INSERT INTO TEMP3 SELECT * from TEMP4;































INSERT INTO TEMP3(category,amount,quantity,cash,charge,advertising, pkey,sortkey) SELECT 'TOTAL', 







sum(amount),SUM(quantity), sum(cash),sum(charge),sum(advertising),4,4 from TEMP4;































INSERT INTO TEMP2(dummy,qty,unitprice, amount, netvat, tax, pk) select concat(' ',category), 







quantity, cash, charge, advertising, amount, pkey from TEMP3 ORDER BY sortkey, category;















SELECT dateSO as 'DATE',	















soID AS 'SO NO.', 















itemname AS 'ITEM DESCRIPTION',















dummy as '',















qty AS 'QTY', 















unit AS 'UNIT', 















unitPrice AS 'UNIT PRICE', 















discount AS '(%)',	















amount AS 'AMOUNT',















NULL,	















netvat AS 'NET OF VAT', 















tax AS 'OUTPUT TAX', 















remarks AS 'REMARKS', 















pk















from TEMP2;















END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_transactionhistory
DROP PROCEDURE IF EXISTS `sp_transactionhistory`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_transactionhistory`(IN `options` vARCHAR(50), IN `p_Item` vARCHAR(50))
BEGIN



-- DECLARE query varchar(1000);



DROP TABLE IF EXISTS TEMP;



CREATE TEMPORARY TABLE TEMP



(



	idcustomer int,



	name varchar(100),



	transdate date,



	transid varchar(15),



	transdesc varchar(10),



	itemname varchar(200),



	qty int,



	unit varchar(10),



	price double(18,2),



	discount int,



	amount double(18,2),



	remarks varchar(250),



	bikeinfo varchar(50),



	idbike int



);



set @query = "INSERT INTO TEMP select a.idCustomer,upper(concat(a.lname,', ',a.fName, IFNULL(IF







(a.midInit='','',concat(' ',a.midInit,'.')),''))) AS name, "; 



set @query = concat(@query,"b.dateso, b.soid, 'SO', d.itemname, c.qty, c.unit,c.unitPrice, 







c.discount, (c.amount-(c.amount*(c.discount/100))) as total,b.payMode,'',0 from tblcustomer a ");



set @query = concat(@query,"left join tblsalesorder b on b.idCustomer=a.idCustomer ");



set @query = concat(@query,"left join tblsales c on b.soid=c.soid ");



set @query = concat(@query,"left join tblitem d on d.code = c.idItem ");



set @query = concat(@query,"where b.soid <> '0' ");



-- set @query = concat(@query,"having name like '%",customer_name, "%'");



PREPARE stmt1 FROM @query;



EXECUTE stmt1;



DEALLOCATE PREPARE stmt1;







set @query = "INSERT INTO TEMP Select a.idCustomer,upper(concat(a.lname,', ',a.fName, IFNULL(IF







(a.midInit='','',concat(' ',a.midInit,'.')),''))) AS name, "; 



set @query = concat(@query,"b.dateRsrv, b.rsrvNo, 'AR', c.itemname, c.qty, '',c.unitPrice, 0, 







c.amount as total,concat(b.status, IFNULL(IF(b.remarks='','', concat(' - ',b.remarks)),'')),'',0 







from tblcustomer a ");



set @query = concat(@query,"left join tblreserveorder b on b.idCustomer=a.idCustomer ");



set @query = concat(@query,"left join tblreserveitems c on c.idRsrv=b.idRsrv ");



-- set @query = concat(@query,"having name like '%",customer_name, "%'");



PREPARE stmt1 FROM @query;



EXECUTE stmt1;



DEALLOCATE PREPARE stmt1;







set @query = "INSERT INTO TEMP select a.idCustomer,upper(concat(a.lname,', ',a.fName, IFNULL(IF







(a.midInit='','',concat(' ',a.midInit,'.')),''))) AS name, ";



set @query = concat(@query,"if(b.dateFinished='0000-00-00',b.dateStarted,b.dateFinished), b.JOID, 







'SVC', '', 1,'Unit',0, b.srvcDscnt, b.grandTotal as total, ");



set @query = concat(@query,"ifnull(b.paymode,b.status), if







(b.idMtrbikes='0','clientbike','soldbike'),IFNULL(if(b.idMtrbikes=0,b.idCustBike,b.idMtrbikes),0) 







");



set @query = concat(@query,"from tblcustomer a "); 



set @query = concat(@query,"left join tbljoborder b on b.idCustomer=a.idCustomer ");



-- set @query = concat(@query,"having name like '%",customer_name, "%'");



PREPARE stmt1 FROM @query;



EXECUTE stmt1;



DEALLOCATE PREPARE stmt1;







UPDATE TEMP a 



set a.itemname = (select model from tblmotorbikes b where a.idbike = b.idMtrbikes)



where a.bikeinfo = 'soldbike';







UPDATE TEMP a 



set a.itemname = (select model from tblcustomerbikes b where a.idbike = b.idCustbike)



where a.bikeinfo = 'clientbike';







DELETE FROM TEMP WHERE transid is null;







DROP TABLE IF EXISTS TEMPFINAL;



CREATE TEMPORARY TABLE TEMPFINAL



	(



		id int NOT NULL AUTO_INCREMENT,



		idcustomer int,



		name varchar(100),



		transdate date,



		transid varchar(15),



		transdesc varchar(10),



		itemname varchar(200),



		qty int,



		unit varchar(10),



		price double(18,2),



		discount int,



		amount double(18,2),



		remarks varchar(250),



		bikeinfo varchar(50),



		idbike int,



	   PRIMARY KEY (`id`)



	)  ENGINE=InnoDB AUTO_INCREMENT=2378 DEFAULT CHARSET=utf8;







if options ='byCustomer' then







	BEGIN



	



		set @query='INSERT INTO TEMPFINAL (idcustomer, name, transdate, transid, transdesc, 







itemname, qty, unit,



		price, discount, amount, remarks, bikeinfo, idbike)



		SELECT idcustomer, name, transdate, transid, transdesc, itemname, qty, unit,



		price, discount, amount, remarks, bikeinfo, idbike



		FROM TEMP 



		WHERE name like''%';



		set @query = concat(@query, p_Item, '%'' ORDER BY transdate');



		--	select @query;



	



		PREPARE stmt1 FROM @query;



		EXECUTE stmt1;



		DEALLOCATE PREPARE stmt1;



		



		SELECT * FROM TEMPFINAL;



	END;



elseif options='byItem' then



	BEGIN



		set @query='INSERT INTO TEMPFINAL (idcustomer, name, transdate, transid, transdesc, 







itemname, qty, unit,



		price, discount, amount, remarks, bikeinfo, idbike)



		SELECT idcustomer, name, transdate, transid, transdesc, itemname, qty, unit,



		price, discount, amount, remarks, bikeinfo, idbike



		FROM TEMP 



		WHERE itemname like''%';



		set @query = concat(@query, p_Item, '%'' ORDER BY transdate');



		--	select @query;



	



		PREPARE stmt1 FROM @query;



		EXECUTE stmt1;



		DEALLOCATE PREPARE stmt1;



		



		SELECT * FROM TEMPFINAL;



	END;



end if;



END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_transactionreport
DROP PROCEDURE IF EXISTS `sp_transactionreport`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_transactionreport`(IN `options` vARCHAR(50), IN `paramFilter` vARCHAR(50), IN `paramSortBy` VARCHAR(50), IN `date_start` DATE, IN `date_end` DATE)
BEGIN



DROP TEMPORARY TABLE IF EXISTS TEMP;



CREATE TEMPORARY TABLE TEMP



(

	transID int,

	transNo varchar(20),

	transDesc varchar(100),

	transDate date,

   locFrom varchar(60),

   locTo varchar(60),

   supplier varchar(150),

   customer varchar(50),

   bikeBrand varchar(150),

   bikeModel varchar(150),

   bikeMake int,

   services text,

   costSrvc double(9,2),

   items varchar(200),

   costItem double(9,2), 

	unit varchar(10),

   qty int,

	category varchar(80),

	brand varchar(80),

	sortkey int		



);



IF options = "pullout" THEN



	IF paramFilter = 'All' THEN

	

		INSERT INTO TEMP(transID, transNo, transDesc, transDate, locFrom, locTo,  customer, items, costItem, unit, 

			qty, category, brand, sortkey) 

		SELECT p.idPullOut, p.pulloutID, 'pullout', p.datePullOut, p.origin, p.destination, p.destination,

			i.itemName, pi.unitPrice, pi.unit, pi.qty, ic.Category, ib.brandName, '1'

		FROM tblpulloutitems pi 

		LEFT JOIN tblpullout p ON p.idPullOut=pi.idPullOut

		LEFT JOIN tblitem i ON i.idItem=pi.idItem

		LEFT JOIN tblitemcategory ic ON ic.idCategory=i.idCategory

		LEFT JOIN tblitembrand ib ON ib.idBrand=i.idBrand;

	

	Else

	

		INSERT INTO TEMP(transID, transNo, transDesc, transDate, locFrom, locTo,  customer, items, costItem, unit, 

			qty, category, brand, sortkey) 

		SELECT p.idPullOut, p.pulloutID, 'pullout', p.datePullOut, p.origin, p.destination, p.destination,

			i.itemName, pi.unitPrice, pi.unit, pi.qty, ic.Category, ib.brandName, '1'

		FROM tblpulloutitems pi 

		LEFT JOIN tblpullout p ON p.idPullOut=pi.idPullOut

		LEFT JOIN tblitem i ON i.idItem=pi.idItem

		LEFT JOIN tblitemcategory ic ON ic.idCategory=i.idCategory

		LEFT JOIN tblitembrand ib ON ib.idBrand=i.idBrand

		WHERE p.datePullOut BETWEEN date_start AND date_end;

		

	END IF;

	

	

	UPDATE TEMP SET sortkey ='2' WHERE category LIKE '%Consign%';

	

   IF  paramSortBy='Category' THEN

   

   	SELECT transID, transNo, transDesc, transDate, locFrom, locTo,  customer, items, costItem, unit, 

		qty, category, brand, sortkey

		FROM TEMP 

		ORDER BY sortkey ASC;

		

   ELSEIF paramSortBy='Brand' THEN

      

		SELECT transID, transNo, transDesc, transDate, locFrom, locTo,  customer, items, costItem, unit, 

		qty, category, brand, sortkey

		FROM TEMP 

		ORDER BY brand ASC;

						

   END IF;



	

ELSEIF options='purchases' THEN

	

	IF paramFilter = 'All' THEN

	

		INSERT INTO TEMP(transID, transNo, transDesc, transDate, supplier, items, costItem, 

			unit, qty, brand, category, sortkey)

	 	SELECT o.idOrder, o.poID, 'purchases', oi.dateReceived, s.supplierName, i.itemName, oi.cost, 

		   u.Unit, oi.quantity, ib.brandName, ic.Category, '1'

		FROM tblordereditems oi

		LEFT JOIN tblorder o ON o.idOrder=oi.idOrder

		LEFT JOIN tblitem i ON i.idItem=oi.idItem

		LEFT JOIN tblunit u ON u.idUnit=oi.idUnit

		LEFT JOIN tblitemcategory ic ON ic.idCategory=i.idCategory

		LEFT JOIN tblitembrand ib ON ib.idBrand=i.idBrand

		LEFT JOIN tblsupplier s ON s.idSupplier=i.idSupplier

		WHERE oi.quantity <> 0;

	

	ELSE 

	

		INSERT INTO TEMP(transID, transNo, transDesc, transDate, supplier, items, costItem, 

			unit, qty, brand, category, sortkey)

	 	SELECT o.idOrder, o.poID, 'purchases', oi.dateReceived, s.supplierName, i.itemName, oi.cost, 

		   u.Unit, oi.quantity, ib.brandName, ic.Category, '1'

		FROM tblordereditems oi

		LEFT JOIN tblorder o ON o.idOrder=oi.idOrder

		LEFT JOIN tblitem i ON i.idItem=oi.idItem

		LEFT JOIN tblunit u ON u.idUnit=oi.idUnit

		LEFT JOIN tblitemcategory ic ON ic.idCategory=i.idCategory

		LEFT JOIN tblitembrand ib ON ib.idBrand=i.idBrand

		LEFT JOIN tblsupplier s ON s.idSupplier=i.idSupplier

		WHERE oi.quantity <> 0

		AND oi.dateReceived BETWEEN date_start AND date_end;

	

	END IF;



	UPDATE TEMP SET sortkey ='2' WHERE category LIKE '%Consign%';

	

   IF paramSortBy='Category' THEN

   

   	SELECT transID, transNo, transDesc, transDate, supplier, items, costItem, 

			unit, qty, brand, category, sortkey

		FROM TEMP 

		ORDER BY category, sortkey ASC;

		

   ELSEIF paramSortBy='Brand' THEN

      

      SELECT transID, transNo, transDesc, transDate, supplier, items, costItem, 

			unit, qty, brand, category, sortkey

		FROM TEMP 

		ORDER BY brand ASC;

	

	ELSEIF paramSortBy='Supplier' THEN

      

      SELECT transID, transNo, transDesc, transDate, supplier, items, costItem, 

			unit, qty, brand, category, sortkey

		FROM TEMP 

		ORDER BY supplier ASC;

	

	

   END IF;

	

END IF;





END//
DELIMITER ;


-- Dumping structure for procedure invndc.sp_viewJO
DROP PROCEDURE IF EXISTS `sp_viewJO`;
DELIMITER //
CREATE DEFINER=`user`@`192.168.1.4` PROCEDURE `sp_viewJO`(IN `params_ID` VARCHAR(50), IN `params_options` varCHAR(50))
BEGIN
/*
==============================================
Updated by: MCA 12.10.2015
-- Billing Statement params "BS"



==============================================
*/

DECLARE Bike_type varchar(50);
IF params_options = 'JO' then
	DROP TEMPORARY TABLE IF EXISTS TEMP;

	CREATE TEMPORARY TABLE TEMP
		(
			JO_No varchar(15),
			clNo varchar(10),
			mbk_id int,
			biketype varchar(25),
			dateStarted date,
			customer varchar(150),
			model varchar(50),
			contactNo varchar(50),
			address text,
			email varchar(50),
			chassis varchar(50),
			engine varchar(50),
			odometer varchar(10),
			yearMk int,
			plateno varchar(15),
			battery varchar(50),
			timein varchar(15),
			prepname varchar(50),
			preposition varchar(50),
			chkname varchar(50),
			chkposition varchar(50),
			apprname varchar(50),
			apprposition varchar(50),
			rcvname varchar(50),
			rcvposition varchar(50)
		);
		INSERT INTO TEMP
		select a.joid, a.clNo, if(a.idMtrbikes="0", a.idCustBike, a.idMtrbikes), if(a.idMtrbikes=0, "Client Bike", "Sold Bike"),a.dateStarted, CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName), 
		null, b.phonenum, b.address, b.emailAddress, NULL, NULL, a.odometer, null, null, a.batteryNo, a.timeIn, a.joPrprdBy, null, 
		a.joChckdBy, null, a.joApprvdBy, null, a.joRcvdBy, null
		FROM tbljoborder a
		LEFT JOIN tblcustomer b ON b.idCustomer=a.idCustomer
		WHERE a.joid = params_ID;
		UPDATE TEMP a
		LEFT JOIN tblemployee b on a.prepname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
		LEFT JOIN tblposition c on c.idPosition = b.idPosition
		set a.preposition = c.position;
UPDATE TEMP a
LEFT JOIN tblemployee b on a.chkname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
LEFT JOIN tblposition c on c.idPosition = b.idPosition
set a.chkposition = c.position;
UPDATE TEMP a
LEFT JOIN tblemployee b on a.apprname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
LEFT JOIN tblposition c on c.idPosition = b.idPosition
set a.apprposition = c.position;
UPDATE TEMP a
LEFT JOIN tblemployee b on a.rcvname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
LEFT JOIN tblposition c on c.idPosition = b.idPosition
set a.rcvposition = c.position;
set Bike_type = (select biketype from TEMP);
	IF Bike_type = "Client Bike" then
		UPDATE TEMP a
		LEFT JOIN tblcustomerbikes b on a.mbk_id = b.idCustBike
		SET a.chassis = b.chassisNo, a.engine=b.engineNo, a.yearMk=b.yearMake, a.plateno = b.plateNo, a.model = b.model;
	else
		UPDATE TEMP a
		LEFT JOIN tblmotorbikes b on a.mbk_id = b.idMtrbikes
		SET a.chassis = b.chassisNo, a.engine=b.engineNo, a.yearMk=b.yearMake, a.plateno = b.plateNo, a.model = b.model;
	end if;
		SELECT * FROM TEMP;

		END IF;	
		IF params_options ='JE' THEN
			DROP TEMPORARY TABLE IF EXISTS TEMP2;
			CREATE TEMPORARY TABLE TEMP2
			(
				JO_No varchar(15),
				JE_No varchar(15),
				clNo varchar(10),
				mbk_id int,
				biketype varchar(25),
				dateStarted date,
				customer varchar(150),
				model varchar(50),
				contactNo varchar(50),
				address text,
				email varchar(50),
				chassis varchar(50),
				engine varchar(50),
				odometer varchar(10),
				yearMk int,
				plateno varchar(15),
				battery varchar(50),
				timein varchar(15),
				timeout varchar(15),		
				prepname varchar(50),
				preposition varchar(50),
				notedname varchar(50),
				notedposition varchar(50),
				apprname varchar(50),
				apprposition varchar(50)
				

			);
INSERT INTO TEMP2
select a.joid, a.jeid, a.clNo, if(a.idMtrbikes="0", a.idCustBike, a.idMtrbikes), if(a.idMtrbikes="0", "Client Bike", "Sold Bike"),a.dateStarted, CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName), 
null, b.phonenum, b.address, b.emailAddress, NULL, NULL, a.odometer, null, null, a.batteryNo, a.timeIn, a.timeOut, a.jePrprdBy, null, 
a.jeNotedBy, null, a.jeApprvdBy, null
FROM tbljoborder a
LEFT JOIN tblcustomer b ON b.idCustomer=a.idCustomer
WHERE a.jeid = params_ID;
	UPDATE TEMP2 a
	LEFT JOIN tblemployee b on a.prepname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
	LEFT JOIN tblposition c on c.idPosition = b.idPosition
	set a.preposition = c.position;
UPDATE TEMP2 a
LEFT JOIN tblemployee b on a.notedname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
LEFT JOIN tblposition c on c.idPosition = b.idPosition
set a.notedposition = c.position;
UPDATE TEMP2 a
LEFT JOIN tblemployee b on a.apprname = (CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName))
LEFT JOIN tblposition c on c.idPosition = b.idPosition
set a.apprposition = c.position;
set Bike_type = (select biketype from TEMP2 LIMIT 1);
	IF bike_type = "Client Bike" then
		UPDATE TEMP2 a
		LEFT JOIN tblcustomerbikes b on a.mbk_id = b.idCustBike
		SET a.chassis = b.chassisNo, a.engine=b.engineNo, a.yearMk=b.yearMake, a.plateno = b.plateNo, a.model = b.model;
	else
		UPDATE TEMP2 a
		LEFT JOIN tblmotorbikes b on a.mbk_id = b.idMtrbikes
		SET a.chassis = b.chassisNo, a.engine=b.engineNo, a.yearMk=b.yearMake, a.plateno = b.plateNo, a.model = b.model;
	end if;
	SELECT * FROM TEMP2;

	END IF;
IF params_options ='BS' THEN
	DROP TEMPORARY TABLE IF EXISTS TEMP3;
	CREATE TEMPORARY TABLE TEMP3
	(
		INV_No varchar(15),
		JO_No varchar(15),
		JE_No varchar(15),
		clNo varchar(10),
		mbk_id int,
		biketype varchar(25),
		dateStarted date,
		dateFinished date,
		customer varchar(150),
		model varchar(50),
		contactNo varchar(50),
		address text,
		email varchar(50),
		chassis varchar(50),
		engine varchar(50),
		odometer varchar(10),
		yearMk int,
		plateno varchar(15),
		battery varchar(50),
		timein varchar(15),
		timeout varchar(15),
		partsTotal double(18,2),
		partsDiscount double(18,2),
		serviceTotal double(18,2),
		serviceDiscount double(18,2),
		grandTotal double(18,2)
	);
INSERT INTO TEMP3
select a.salesOr, a.joid, a.jeid, a.clNo, if(a.idMtrbikes="0", a.idCustBike, a.idMtrbikes), 
if(a.idMtrbikes="0", "Client Bike", "Sold Bike"), a.dateStarted, a.dateFinished, 
CONCAT(b.fName, " ", ifnull(concat(b.midInit, ". ")," "), b.lName), 
null, b.phonenum, b.address, b.emailAddress, NULL, NULL, a.odometer, null, null, a.batteryNo, a.timeIn, a.timeOut, 
a.partsTotal, a.partDscnt,a.srvcTotal, a.srvcDscnt, a.grandTotal
FROM tbljoborder a
LEFT JOIN tblcustomer b ON b.idCustomer=a.idCustomer
WHERE a.jeid = params_ID;
	set Bike_type = (select biketype from TEMP3 LIMIT 1);
		IF bike_type = "Client Bike" then
			UPDATE TEMP3 a
			LEFT JOIN tblcustomerbikes b on a.mbk_id = b.idCustBike
			SET a.chassis = b.chassisNo, a.engine=b.engineNo, a.yearMk=b.yearMake, a.plateno = b.plateNo, a.model = b.model;
		else
			UPDATE TEMP3 a
			LEFT JOIN tblmotorbikes b on a.mbk_id = b.idMtrbikes
			SET a.chassis = b.chassisNo, a.engine=b.engineNo, a.yearMk=b.yearMake, a.plateno = b.plateNo, a.model = b.model;
		end if;
		SELECT * FROM TEMP3;

		END IF;
END//
DELIMITER ;


-- Dumping structure for table invndc.tblbikemodels
DROP TABLE IF EXISTS `tblbikemodels`;
CREATE TABLE IF NOT EXISTS `tblbikemodels` (
  `idBrand` int(3) DEFAULT NULL,
  `idModel` int(3) NOT NULL DEFAULT '0',
  `model` varchar(250) DEFAULT NULL,
  `details` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`idModel`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblbikemodels: 14 rows
/*!40000 ALTER TABLE `tblbikemodels` DISABLE KEYS */;
INSERT INTO `tblbikemodels` (`idBrand`, `idModel`, `model`, `details`) VALUES
	(22, 1, 'GPR', 'Ducati Desmosedici RR\r'),
	(22, 2, 'Old HYM', 'Ducati Hypermotard 796  |  Ducati Hypermotard 1100  | Ducati Hypermotard 1100 EVO\r'),
	(22, 3, 'MR', 'Ducati Monster 696  | Ducati Monster 796 | Ducati Monster 796 | Ducati Monster 1100 | Ducati Monster 1100 EVO\r'),
	(22, 4, 'Old MTS', 'Ducati Multistrada 1000 | Ducati Multistrada 110\r'),
	(22, 5, 'DVL', 'Ducati Ducati Diavel\r'),
	(22, 6, 'MS', 'Ducati Multistrada 1200\r'),
	(22, 7, 'SBK', 'Ducati Super Bike 848 | Ducati Super Bike 1098 | Ducati Super Bike 1198\r'),
	(22, 8, 'SF', 'Ducati Streetfighter 1098 | Ducati Streetfighter 848\r'),
	(22, 9, '1199', 'Ducati 1199 Panigale\r'),
	(22, 10, 'New HYM', 'Ducati Hypermotard Hyperstrada Hypermotard SP\r'),
	(22, 11, '899', 'Ducati 899 Panigale\r'),
	(22, 12, 'SC', 'Ducati Sport Classic\r'),
	(22, 13, 'SS', 'Ducati Super Sport\r'),
	(22, 14, 'ST', 'Ducati Sport Touring\r');
/*!40000 ALTER TABLE `tblbikemodels` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcharges
DROP TABLE IF EXISTS `tblcharges`;
CREATE TABLE IF NOT EXISTS `tblcharges` (
  `idCharges` int(3) DEFAULT NULL,
  `charges` varchar(25) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcharges: 1 rows
/*!40000 ALTER TABLE `tblcharges` DISABLE KEYS */;
INSERT INTO `tblcharges` (`idCharges`, `charges`) VALUES
	(1, 'extra charges');
/*!40000 ALTER TABLE `tblcharges` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcity
DROP TABLE IF EXISTS `tblcity`;
CREATE TABLE IF NOT EXISTS `tblcity` (
  `city` varchar(50) DEFAULT NULL,
  `provinces` varchar(50) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcity: 10 rows
/*!40000 ALTER TABLE `tblcity` DISABLE KEYS */;
INSERT INTO `tblcity` (`city`, `provinces`) VALUES
	('Cagayan de oro', 'Misamis Oriental'),
	('Butuan City', 'Agusan Valley'),
	('Zamboanga City', 'Zamboanga del Sur'),
	('Cebu City', 'Cebu'),
	('Iligan City', 'Lanao del Norte'),
	('Valencia City', 'Bukidnon'),
	('Cotabato', 'South Cotabato'),
	('Manila', 'Metro Manila'),
	('Pasay City', 'Luzon'),
	('Ipil ', 'Sibugay');
/*!40000 ALTER TABLE `tblcity` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcompany
DROP TABLE IF EXISTS `tblcompany`;
CREATE TABLE IF NOT EXISTS `tblcompany` (
  `idCmpny` int(5) DEFAULT NULL,
  `company` varchar(100) DEFAULT NULL,
  `detail` varchar(200) DEFAULT NULL,
  `address1` varchar(150) DEFAULT NULL,
  `address2` varchar(150) DEFAULT NULL,
  `TIN` varchar(20) DEFAULT NULL,
  `phoneNum` varchar(50) DEFAULT NULL,
  `faxNum` varchar(15) DEFAULT NULL,
  `website` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcompany: ~4 rows (approximately)
/*!40000 ALTER TABLE `tblcompany` DISABLE KEYS */;
INSERT INTO `tblcompany` (`idCmpny`, `company`, `detail`, `address1`, `address2`, `TIN`, `phoneNum`, `faxNum`, `website`) VALUES
	(1, 'SMSi', 'Solutions Management Systems Inc.', 'Cagayan de Oro City', NULL, NULL, '(088) 856-1662', '0', 'www.smsi.com.ph'),
	(2, 'NDC - CDO', 'Dealership', 'Blk.1, Lot 19, Xavier Estates, Masterson Avenue,', ' Cagayan de Oro City', '407-720-147', '(088) 880-6378', 'NA', 'www.norminringmotorbikes.com'),
	(3, 'AFC', 'Amaara Financial Corporation', 'Davao City', NULL, NULL, '867565', '6786756', 'www.afc.com.ph'),
	(4, 'NDC - DVO', 'Dealership', 'Davao City', NULL, NULL, '0', '0', 'www.norminring.com'),
	(5, 'NDC-ZBO', 'NDC BRANCH', 'Shell One Stop Lobregat Highway Divisoria', 'Zamboanga City 7000', '407-720-147-002', '0917-703-8681/0947-999-9632', 'none', 'www.norminringmotorbikes.com');
/*!40000 ALTER TABLE `tblcompany` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcourier
DROP TABLE IF EXISTS `tblcourier`;
CREATE TABLE IF NOT EXISTS `tblcourier` (
  `idCourier` int(3) NOT NULL DEFAULT '0',
  `courier` varchar(50) DEFAULT NULL,
  `details` varchar(200) DEFAULT NULL,
  `address` varchar(400) DEFAULT NULL,
  `telNum` varchar(15) DEFAULT NULL,
  `faxNum` varchar(15) DEFAULT NULL,
  `website` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`idCourier`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcourier: 7 rows
/*!40000 ALTER TABLE `tblcourier` DISABLE KEYS */;
INSERT INTO `tblcourier` (`idCourier`, `courier`, `details`, `address`, `telNum`, `faxNum`, `website`) VALUES
	(1, 'LBC-Pabayo Branch', 'Pabayo Branch DIV 1001', 'Tirso-Neri sts., Cagayan de Oro City', '858768', '858768', 'na'),
	(2, 'JRL', 'via JRL', 'MNL-CDO DVO-CDO', 'n/a', 'n/a', ''),
	(3, 'Air21', 'n/a', 'n/a', 'n/a', 'n/a', ''),
	(4, 'None', 'n/a', 'n/a', 'n/a', 'n/a', ''),
	(5, 'IOP', 'Ivan O Paredes', 'CDO-Kubo', '09175271661', 'n/a', ''),
	(6, 'c/o Eumir Motopimp', 'GMIC', 'n/a', 'n/a', 'n/a', ''),
	(7, 'c/o AVL', 'Assistant General Manager', 'Davao', 'n/a', 'n/a', '');
/*!40000 ALTER TABLE `tblcourier` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcustomer
DROP TABLE IF EXISTS `tblcustomer`;
CREATE TABLE IF NOT EXISTS `tblcustomer` (
  `idCustomer` int(8) NOT NULL DEFAULT '0',
  `fName` varchar(50) DEFAULT NULL,
  `midInit` varchar(2) DEFAULT NULL,
  `lName` varchar(50) DEFAULT NULL,
  `address` varchar(250) DEFAULT NULL,
  `phonenum` varchar(20) DEFAULT NULL,
  `emailAddress` varchar(50) DEFAULT NULL,
  `landlinenum` varchar(13) DEFAULT NULL,
  `birthdate` date DEFAULT NULL,
  `city` varchar(50) DEFAULT NULL,
  `province` varchar(50) DEFAULT NULL,
  `region` varchar(20) DEFAULT NULL,
  `tin` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`idCustomer`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcustomer: 157 rows
/*!40000 ALTER TABLE `tblcustomer` DISABLE KEYS */;
INSERT INTO `tblcustomer` (`idCustomer`, `fName`, `midInit`, `lName`, `address`, `phonenum`, `emailAddress`, `landlinenum`, `birthdate`, `city`, `province`, `region`, `tin`) VALUES
	(1, 'GILBERT', '', 'BERLIN', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(2, 'KIM', '', 'ARIMAS', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(3, 'ARNIE', '', 'ALVIAR', 'Putik Zamboanga CIty', '', '', '', '0000-00-00', '', '', '', '_'),
	(4, 'NURELDIN', '', 'AFIF', 'TETUAN, ZAMBOANGA CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(5, 'JOSHUA', '', 'ORTEGA', 'STA MARIA, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(6, 'GIRLIE', '', 'TOLOSA', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(7, 'EDUARDO', '', 'AMUDDIN', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(8, 'JAILANI', '', 'MUKTADER', 'TUMAGA, Z.C', '', '', '', '0000-00-00', '', '', '', NULL),
	(9, 'BONG', '', 'EDDING', 'TUMAGA, Z.C', '', '', '', '0000-00-00', '', '', '', NULL),
	(10, 'FERJON ', '', 'AHMAD', 'MALUSO, BASILAN', '', '', '', '0000-00-00', '', '', '', NULL),
	(11, 'LIBRADO', '', 'VALENTINO', 'MT-DIPOLOG', '', '', '', '0000-00-00', '', '', '', NULL),
	(12, 'CARLOS', '', 'PARAGAS', 'ZAMBOANGA DEL SUR', '', '', '', '0000-00-00', '', '', '', NULL),
	(13, 'SEITH FREDERICK', '', 'JALOSJOS', 'DAKAK PARK & BEACH RESORT, DIPOLOG CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(14, 'EDGAR', '', 'GUEVARA', 'DAKAK PARK & BEACH RESORT, DIPOLOG CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(15, 'ABDULHAN', '', 'PINGLI', 'TALABAAN, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(16, 'NDC', '', 'ZAMBAOANGA', 'ZBO BRANCH', '', '', '', '0000-00-00', '', '', '', NULL),
	(17, 'REGIE', '', 'TALANG', 'IPIL', '', '', '', '0000-00-00', '', '', '', NULL),
	(18, 'ABUBAZAR', 'P', 'HASIM', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(19, 'JAILANI', '', 'MUTAKDER', 'TUMAGA, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(20, 'JOHN', 'S', 'ATIENZA', 'PUTIK ZAMBOANGA CITY', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(21, 'ROBERTO', '', 'ANDRADA', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(22, 'OLIVER', '', 'LIM', 'TALON LOOP, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(23, 'IRIS', 'V', 'TRINIDAD', 'Meroseville Subd. MCLL Highway Divisoria Zamboanga CIty', '0917-701-4052', 'cooljamice@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(24, 'AL QAZU', '', 'MOHAMAD', 'TALON TALON, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(25, 'KAISAR', '', 'BARRA', 'MAMPONG, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(26, 'ALLAN', '', 'VARGAS', 'PUTIK, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(27, 'GLENN', 'L', 'CHIONG', 'GOV. LIM AVENUE, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(28, 'JULMAKLI', '', 'SALI', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(29, 'BENSOUD', '', 'AJIHIL', 'Bongao Tawi-tawi', '0917-885-9998', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(30, 'JONRIMALO', '', 'TEJERO', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(31, 'YOUSEF', '', 'IBRAHIM', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(32, 'AL-SABU', '', 'IKING', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(33, 'MUSIN', '', 'MARTIN', 'SAN JOSE NAVARRO, Z.C.', '', '', '', '0000-00-00', '', '', '', NULL),
	(34, 'ALSON', '', 'ESPERANZA', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(35, 'ARNIE', 'V', 'LAYCO', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(36, 'HARIE', 'A', 'BUD', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(37, 'GIBSON', '', 'SALVADOR', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(38, 'MARTIN', '', 'MUSIN', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(39, 'HENRY', '', 'JUMAWAN', 'TUMAGA ZAMBOANGA CITY', '09177046506', 'hjumawan@yahoo.ocm', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(40, 'MOH MONEL', 'B', 'AL-QAZIR', '', '', '', '', '0000-00-00', '', '', '', '_'),
	(41, 'YU', '', 'DR. YU', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(42, 'MUAMMOR', '', 'SAHIBON', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(43, 'JOEVELLE ', '', 'SUMERGIDO', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(44, 'HECTOR', '', 'MAG AWAY', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(45, 'SAM ', '', 'DANTES', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(46, 'ARNOLD', 'C', 'CASTILLO', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(47, 'JAYSON', '', 'GO', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(48, 'KAENAR', '', 'VLAO', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(49, 'PAGADIAN', '', 'MT', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(50, 'EDWARD', '', 'JAYME', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(51, 'TOTO', '', 'ESPINOSA', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(52, 'JEFFREY ', '', 'ALAGASI', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(53, 'YAHCOB', '', 'TABALLANG', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(54, 'SILVERIO', '', 'BOBIER', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(55, 'AL-FRAZED', '', 'HAJIM', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(56, 'ALVN', '', 'MORALES', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(57, 'AL', '', 'TALIB', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(58, 'ALVIN', '', 'MORALES', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(59, 'RUBEN', '', 'CALLETOR', 'POB. TUKURAN ZAMBO. DEL SUR', '', '', '', '0000-00-00', '', '', '', NULL),
	(60, 'JOSEPH', 'V', 'DEL ROSARIO JR.', 'ZDN', '', '', '', '0000-00-00', '', '', '', NULL),
	(61, 'RUBIN', '', 'CALLETOR', 'POB. TUKURAN ZAMBO. DEL SUR', '', '', '', '0000-00-00', 'Cagayan de oro', 'Misamis Oriental', 'X', NULL),
	(62, 'TALANIX', '', 'TALANIX', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(63, 'NASSER', 'P', 'SULTAN', 'CARMINCHI ST. BALINGBING DRIVE ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(64, 'JAMES', '', 'ABAD', 'ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(65, 'AMING', '', 'Rass', 'ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(66, 'ERNIE', '', 'SUMALINOG', 'DIPLAHAN ZAMBO. SIBUGAY', '', '', '', '0000-00-00', '', '', '', NULL),
	(67, 'MRS. TALANIA', '', 'MRS. TALANIA', ' ZAMBO. SIBUGAY', '', '', '', '0000-00-00', '', '', '', NULL),
	(68, 'RONALD CHRISTOPHER GLENN', '', 'ARIOSA', 'PAGADIAN CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(69, 'JEFFREY', '', 'CHIONG', 'TETUAN, ZAMBANGA CITY', '0917-720-6818', '', '', '0000-00-00', '', '', '', '_'),
	(70, 'REDZMAR', 'T', 'ANNI', 'MERCEDES ZAMBO.CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(71, 'ARNOLD', '', 'ABAYON', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(72, 'RONALD', '', 'SANTOS', 'TETUAN ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(73, 'MANNY', '', 'SUMAPO', 'BASILAN', '', '', '', '0000-00-00', '', '', '', NULL),
	(74, 'TESS', '', 'MAGAWAY', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(75, 'OMAR', '', 'ISTAROL', 'GUIWAN ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(76, 'BANJAMIN', 'T', 'VENTURA', 'CANELAR ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(77, 'ABUBAZAR', '', 'HESIN', '', '', '', '', '0000-00-00', '', '', '', NULL),
	(78, 'BONY', 'H', 'SEBA', 'ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(79, 'NOLY', '', 'SUMBILLO', 'ZAMBO. CITY', '', '', '', '0000-00-00', '', '', '', NULL),
	(80, 'RHODEL ', 'L', 'CANTILA', 'Solera St., Sta Lucia District, Pagadian City', '', '', '', '0000-00-00', '', '', '', NULL),
	(81, 'JACOB', 'K', 'YEO', '551-A CANELAR MORET, ZAMBOANGA CITY', '', '', '', '0000-00-00', 'ZAMBOANGA CITY', '', '', NULL),
	(82, 'NORBIDEIRI', 'B', 'EDDING', 'MAESTRA VICENTA EXT. STAMARIA', '', '', '', '0000-00-00', 'ZAMBOANGA CITY', '', '', NULL),
	(83, 'DEVELOPMENT', 'C', 'NORMINRING', 'Shell One Stop SHop Lobregat Highway Divisoria, Zamboanga City', '0917-7038-681', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(84, 'ABDELBASSER', 'B', 'JAMJIRON', 'PARAISO HOME SUBD. TUMAGA', '', '', '', '0000-00-00', 'ZAMBOANGA CITY', '', '', NULL),
	(85, 'Bong', '', 'Tan', 'Sta MAria,Zambo City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(86, 'Bong', '', 'Tan', 'Sta MAria,Zambo City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(87, 'Ismael', '', 'Asmadi', 'Recodo, Zamboanga City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(88, 'Ednurkhan', '', 'Muksan', 'Zamboanga City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(89, 'Teddy ', 'D', 'Vergara Jr', 'Tickwas, Dumalinao, Zamboanga City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(90, 'RICSON', 'L', 'TIMOSAN', 'Gumamela St., Villa Sta Maria, Zambo City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(91, 'Kaiser', 'S', 'Hataman', 'Aguada Brgy Isabela City, Basila', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(92, 'ARNOLD', 'C', 'CASTILLO', 'Pob Titay, Zamboanga Sibugay Province', '091776060135', 'arnoldcastillo1379@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(93, 'Haber', '', 'Asarul', 'Sta Maria compund, Zambo City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(94, 'Javier ', 'A', 'Rasul', 'Suterville, Campo Islam, Zamboanga City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(95, 'Jen', 'P', 'Dantes', 'Cagayan De ORo City', '', '', '', '0000-00-00', 'Cagayan de oro', 'Misamis Oriental', 'X', NULL),
	(96, 'Nureblin ', '', 'Afif', 'TETUAN, ZAMBOANGA CITY', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(97, 'Nureblin ', '', 'Afif', 'TETUAN, ZAMBOANGA CITY', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(98, 'GARY ', 'B', 'CHUA', 'CALLE PAZ BARANGAY LUNZURAN, ZAMBOANGA CITY', '09177245880', 'gchuamd@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(99, 'ROD ANTHONY ', 'A', 'DIOLATA', 'GUIWAN DAISY ROAD, ZAMBOANGA CITY', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(100, 'NORIEL', '', 'CANDIDO', 'TALON-TALON, ZAMBOANGA CITY', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(101, 'JULIET', 'G', 'BAÑOS', 'MANICAHAN, ZAMBOANGA CITY', '09177079115', 'wom_bike@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(102, 'SERGIO ', 'A', 'GENERALE JR.', 'BIKE STOP MAGNA CENTER P. RODRIGUEZ ST., ZAMBOANGA CITY', '09173547371', 'sagjr8091@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(103, 'Teddy ', 'D', 'Vergara Jr', 'Tickwas, Dumalinao, Zamboanga City', '', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', NULL),
	(104, 'JOSEPH', '', 'SIMBULAN', 'KORONADAL CITY', '0917-621-2439', '', '', '0000-00-00', '', 'South Cotabato', 'XII', ''),
	(105, 'ALICE', 'E', 'ARANETA', 'OBL LA CASA SUBD. TUMAGA-LUNZURAN ROAD, ZAMBOANGA CITY', '0917-722-0874', 'ecila2008@yahoo.com', '926-0328', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '133-248-038'),
	(106, 'ALMUSAWWIR ', 'M', 'BUCLAO', 'KAKUYAGAN JOLO SULU ', '0927-806-1301', '', '', '0000-00-00', '', '', '', ''),
	(107, 'NELSON', 'K', 'ROLLO', 'SOUTHCOM VILLAGE, ZAMBOANGA CITY', '09366488137', 'kidlatsagisag@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(108, 'GARY ', 'B', 'CHUA', 'CALLE PAZ BARANGAY LUNZURAN, ZAMBOANGA CITY', '09177245880', 'gchuamd@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(109, 'GARY ', 'B', 'CHUA', 'CALLE PAZ BARANGAY LUNZURAN, ZAMBOANGA CITY', '09177245880', 'gchuamd@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(129, 'Resty Miguel', 'A', 'Nogra', 'Tugbungan/ PSO Vitale Z.C', '09055945523', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(119, 'Wilson Vic', 'B', 'Bazam', '13 Billard Dr. Baliwasan', '09156606572', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(111, 'Terence', 'S', 'Luy', 'TETUAN Z.C', '0917-257-7222', 'terenceluy@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(112, 'AL QAZIR ', 'B', 'MOH. MONEL', 'Logoy Grande Talon-Talon, Zamboanga City ', '0917-500-5031', 'boxtyper@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(130, 'Rafael', 'T', 'Manzano', 'Paseo De Nazareth Zamboanga CIty', '0921-854-5978', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(115, 'ABDULGAFAR', 'A', 'MOHAMMAD', 'Unit 426-B Sea Residences, MOA, Pasay CIty/ Enriquez Drive Sta. Catalina, Zamboanga City', '0977-125-9961', '', '', '0000-00-00', 'Pasay City', 'Luzon', 'NCR', ''),
	(116, 'Regie', '', 'Talania', 'Titay Zamboanga Sibugay', '09175994764', '', '', '0000-00-00', 'Ipil ', 'Sibugay', 'IX', ''),
	(117, 'Muhamad Ali', 'M', 'Albar', 'Canelar Moret, Zamboanga City', '0905640686', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(118, 'Junaidi ', 'H', 'Cadir', 'Taguiti Vitali District, Zamboanga CIty', '09352310779', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(120, 'Mc Delter', '', 'Pabatao', 'Salug Zamboanga del Norte', '09292769338', '', '', '0000-00-00', '', 'Zamboanga Del Norte', 'IX', '_'),
	(121, 'Arcel', 'C', 'Arcillas', 'Tumaga Porcentro, Zamboanga City', '09177861366 ', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '296-183-894'),
	(122, 'Saudi', 'S', 'Kurais', 'Arena S. Blanco Zamboanga City', '09068376300', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(123, 'RAMON', '', 'LUY', 'Sta. Maria, Zamboanga City', '09177100585', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(124, 'MANILA TEACHERS', '', 'ZAMBOANGA ', 'BALIWASAN, ZAMBOANGA CITY', '', '', '062-992-1038', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(125, 'MANILA TEACHERS', '', 'ZAMBOANGA ', 'BALIWASAN, ZAMBOANGA CITY', '', '', '062-992-1038', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(126, 'Jullius', 'V', 'Bumatay', 'San Roque, Zamboanga City', '0947-255-4895', 'analiza.bumatay@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '263-298-022'),
	(127, 'Arnold ', 'G', 'Manantan', '28 Early Bird Putik, Zamboanga City', '0917-799-9271', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(128, 'Muhi', 'M', 'Tah', 'Mercedes, Zamboanga City', '0917-282-0478', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(131, 'Alex', '', 'Chin', 'Zamboanga CIty', '0918-915-5118', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(132, 'Elfred', 'A', 'Esteban', 'Poblacion Bayog, Zamboanga Del Sur', '0916-272-8971', '', '', '0000-00-00', 'Pagadian City', 'Zamboanga del Sur', 'IX', '_'),
	(133, 'Moh. Isahac', 'B', 'Maharail', '3rd St. San Roe Subd. San Roque, Zamboanga CIty', '0975-226-4734', 'jan.maharail@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '918-501-131'),
	(134, 'Mylene', 'P', 'Ramirez', 'Navarro Extension Sta. Maria, Zamboanga City', '0917-882-8055', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '438-315-062'),
	(135, 'Joeter', '', 'Cardenas', 'Talisayan, Zamboanga City ', '09167088718', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(136, 'JEFFERSON ', 'S', 'AGTOTO', 'IPIL, ZAMBOANGA SIBUGAY ', '', '', '333-2283', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(137, 'DEVELOPMENT', 'C', 'NORMINRING', 'Shell One Stop SHop Lobregat Highway Divisoria, Zamboanga City', '0917-7038-681', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(138, 'ARNOLD', 'C', 'CASTILLO', 'Pob. Titay, Zamboanga Sibugay Province', '091776060135', 'arnoldcastillo1379@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(139, 'Francis ', 'F', 'Jamang', 'Tetuan, Zamboanga City', '0905-824-7930', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(140, 'Al Nasal ', 'A', 'Salim', 'Zone II Tulay, Jolo Sulu ', '0915-908-4734', 'jaisar13.2015@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '942-975-192'),
	(141, 'DEVELOPMENT', 'C', 'NORMINRING', 'Shell One Stop SHop Lobregat Highway Divisoria, Zamboanga City', '0917-7038-681', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(142, 'Jullius', 'V', 'Bumatay', 'San Roque, Zamboanga City', '0947-255-4895', 'analiza.bumatay@yahoo.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '263-298-022'),
	(143, 'Norman Olliver ', 'H', 'Adlaon ', 'Tawagan Norte, Labangan Zamboanga del Sur ', '0917-781-5382', '', '', '0000-00-00', '', 'Zamboanga del Sur', '', ''),
	(144, 'Jerico Kier ', 'G', 'Nono', 'Lot 6 Block 4 A&W Subdivision Putik, Zamboanga City', '09059444623', 'jeconono@gmail.com', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '401-165-047'),
	(145, 'Carlos', '', 'Paragas', 'Margosatubig, Zamboanga del Sur ', '0908-353-4790', '', '', '0000-00-00', '', 'Zamboanga del Sur', '', ''),
	(146, 'Daniel', 'F', 'Ilagan ', 'Daisy Road Guiwan, Zamboanga City', '0917-879-1557', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(147, 'Alinaser ', 'J', 'Talib', '181 Magnolia Drive Suterville, Zamboanga City', '0927-776-8162', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '946-757-464'),
	(148, 'Enrico', '', 'Sta. Elena ', 'Putik, Zamboanga City', '0917-887-7470', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(149, 'Jing-Jong', '', 'Alibasa', 'MDAO Village Putik, Zamboanga City', '0917-952-3677', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(150, 'Alvin', '', 'Villagracia ', 'Baliwasan, Zamboanga City', '09354834375', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', '_'),
	(151, 'Julius ', '', 'Daque ', 'Davao City', '', '', '', '0000-00-00', '', '', '', ''),
	(152, 'Jenner', '', 'Moneba', 'Davao City', '', '', '', '0000-00-00', '', '', '', ''),
	(153, 'Hanie', 'A', 'Bud', 'Cabatangan, Zamboanga City ', '09162996916 ', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(154, 'Manuel ', 'L', 'Verar Jr. ', 'San Jose Road, Zamboanga City ', '0917-727-4008', '', '', '0000-00-00', 'Zamboanga City', 'Zamboanga del Sur', 'IX', ''),
	(155, 'Leo Alfie ', '', 'Quipanes ', 'Zamboanga City ', '', '', '', '0000-00-00', '', '', '', ''),
	(156, 'Leo Alfie ', '', 'Quipanes ', 'Zamboanga City ', '', '', '', '0000-00-00', '', '', '', ''),
	(157, 'Leo Alfie ', '', 'Quipanes', 'Zamboanga City', '', '', '', '0000-00-00', '', '', '', ''),
	(158, 'Leo Alfie ', '', 'Quipanes', 'Zamboanga City', '', '', '', '0000-00-00', '', '', '', ''),
	(159, 'Leo Alfie ', '', 'Quipanes ', 'Zamboanga City', '', '', '', '0000-00-00', '', '', '', ''),
	(160, 'Leo Alfie ', '', 'Quipanes ', 'Zamboanga City ', '', '', '', '0000-00-00', '', '', '', '');
/*!40000 ALTER TABLE `tblcustomer` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcustomerbikes
DROP TABLE IF EXISTS `tblcustomerbikes`;
CREATE TABLE IF NOT EXISTS `tblcustomerbikes` (
  `idCustBike` int(15) DEFAULT NULL,
  `model` varchar(100) DEFAULT NULL,
  `yearMake` int(4) DEFAULT NULL,
  `color` varchar(25) DEFAULT NULL,
  `chassisNo` varchar(30) DEFAULT NULL,
  `plateNo` varchar(15) DEFAULT NULL,
  `engineNo` varchar(30) DEFAULT NULL,
  `orcrNo` varchar(30) DEFAULT NULL,
  `ccDisp` varchar(30) DEFAULT NULL,
  `insurance` varchar(50) DEFAULT NULL,
  `otherInsur` varchar(50) DEFAULT NULL,
  `dateExpiry` date DEFAULT NULL,
  `dateAdded` date DEFAULT NULL,
  `remarks` text,
  `dateUpdated` date DEFAULT NULL,
  `idBrand` int(10) DEFAULT NULL,
  `idCustomer` int(15) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcustomerbikes: 66 rows
/*!40000 ALTER TABLE `tblcustomerbikes` DISABLE KEYS */;
INSERT INTO `tblcustomerbikes` (`idCustBike`, `model`, `yearMake`, `color`, `chassisNo`, `plateNo`, `engineNo`, `orcrNo`, `ccDisp`, `insurance`, `otherInsur`, `dateExpiry`, `dateAdded`, `remarks`, `dateUpdated`, `idBrand`, `idCustomer`) VALUES
	(1, 'Italjet Formula', 2014, 'white', 'ZJTFRBSE6BL500072*', 'NONE', 'LJ1P52QMI*1500164*', '', '125', '', '', '0000-00-00', '2015-09-10', '', '0000-00-00', 49, 63),
	(2, 'Monster 795', 2014, 'Red', 'ML0M1004ADTOO2860', 'LA 38988', 'ZDM796A2D002971', '', '795', '', '', '0000-00-00', '2015-09-10', '', '0000-00-00', 7, 87),
	(3, 'Ktm Freeride 350', 2014, 'Orange', 'VBKFRA40XEM208935', 'LC26942', '4-720*49893', '', '350', '', '', '0000-00-00', '2015-09-10', '', '0000-00-00', 1, 23),
	(4, 'Ktm Duke 200 Non Abs ', 2014, 'Orange', 'VBKJUC405ECC020883', 'none', '4-906*52193', '', '200', '', '', '0000-00-00', '2015-09-11', '', '0000-00-00', 1, 94),
	(5, 'Ktm Duke 200 Non Abs', 2014, 'Orange', 'VBKJUC400EC009225', 'NC 14582', '4-906*039429*', '', '200', '', '', '0000-00-00', '2015-09-11', '', '0000-00-00', 1, 14),
	(6, 'RC 200 NON-ABS BLACK ', 2015, 'BLACK ', 'VBKJYC401FC006257', '', '5-906*01475*', '', '200', '', '', '0000-00-00', '2015-09-11', '', '0000-00-00', 1, 89),
	(7, 'KTM DUKE 200', 2014, 'WHITE', 'VBKTUC405EC012542', 'LC 25325', '4-906*42682', '', '200', '', '', '0000-00-00', '2015-09-18', '', '0000-00-00', 1, 39),
	(8, 'Fz 09', 2014, 'Orange', 'JYARN33E1EA001902', '', 'N702E-002500', '', '900', '', '', '0000-00-00', '2015-09-21', '', '0000-00-00', 29, 83),
	(9, 'Formula 125', 2015, 'Red/White', 'ZJTFRBSE3BL500059', '', 'LJ1P52QMI*15000228*', '', '125', '', '', '0000-00-00', '2015-09-21', '', '0000-00-00', 42, 0),
	(10, 'Formula 125', 2015, 'Red/White', 'ZJTFRBSE3BL500059', '', 'LJ1P52QMI*15000228*', '', '125', '', '2015-09-21', '0000-00-00', '2015-09-21', '', '0000-00-00', 42, 82),
	(11, 'FREERIDE', 2014, 'WHITE/ORANGE', 'VBKFRA405EM208910', 'LC 62000', '4-720*49955*', '676328833 / 224502320', '350', '', '', '0000-00-00', '2015-09-22', '', '0000-00-00', 1, 102),
	(12, 'FREERIDE', 2014, 'WHITE/ORANGE', 'VBKFRA405EM208910', 'LC 62000', '4-720*49955*', '676328833 / 224502320', '350', '', '2015-09-22', '0000-00-00', '2015-09-22', '', '0000-00-00', 42, 0),
	(13, 'SCRAMBLER FULL THROTTLE', 2015, 'BLACK/YELLOW', 'MDL0K100AAFT002107', '', 'ML0800A2D*000944*', '', '821', '', '', '0000-00-00', '2015-09-22', '', '0000-00-00', 7, 104),
	(14, 'SCRAMBLER FULL THROTTLE', 2015, 'BLACK/YELLOW', 'MDL0K100AAFT002107', '', 'ML0800A2D*000944*', '', '821', '', '', '0000-00-00', '2015-09-22', '', '0000-00-00', 7, 104),
	(15, 'DUKE 200 NON-ABS ', 2012, 'ORANGE', 'VBKJUC4F5CC016446', 'NA 14335', '2-906*15793*', '', '200', '', '2015-09-22', '0000-00-00', '2015-09-22', '', '0000-00-00', 1, 69),
	(16, 'DUKE 200 NON-ABS ', 2014, 'WHITE ', 'VBKJUC401EC027832', '', '4-906*58707', '', '200', '', '', '0000-00-00', '2015-09-22', '', '0000-00-00', 1, 105),
	(17, 'RC 200 NON-ABS', 2015, 'BLACK', 'VBKJYC405FC006231', '', '5-906*01428*', '', '200', '', '', '0000-00-00', '2015-09-22', '', '0000-00-00', 1, 83),
	(18, 'DUKE 200 NON-ABS', 2014, 'WHITE', 'VBKJUC404EC009356', 'NC 14542', '4-906*39651', '', '200', '', '', '0000-00-00', '2015-09-23', '', '0000-00-00', 1, 111),
	(19, 'Duke 200 Non-abs ', 2014, 'Orange ', 'VBKJUC400EC009676', 'NC 14771', '4-906*40752*', '', '200', '', '', '0000-00-00', '2015-09-28', '', '0000-00-00', 1, 112),
	(20, 'Duke 390 Abs ', 2014, 'White', 'VBKJGJ400EC22678', 'LC 37084', '4-902*12857*', '', '390', '', '', '0000-00-00', '2015-09-28', '', '0000-00-00', 1, 83),
	(21, 'Duke 200 Non-abs ', 2012, 'Orange', 'VBKJUC4C6CC009592', '5661 LX', '2-906*08806*', '', '200', '', '', '0000-00-00', '2015-09-29', '', '0000-00-00', 1, 113),
	(22, 'Duke 200 Non-abs ', 2012, 'Orange', 'VBKJUC4C6CC009592', '5661 LX', '2-906*08806*', '', '200', '', '2015-09-29', '0000-00-00', '2015-09-29', '', '0000-00-00', 42, 114),
	(23, 'KTM DUke 200', 2012, 'Orange', 'VBKJUC4CGCC009592', 'LX 5661', '2-906*08806', '', '200', '', '', '0000-00-00', '2015-10-05', '', '0000-00-00', 1, 115),
	(24, 'KTM RC 200', 2015, 'BLACK', 'VBKJYC401FC006274', 'LC 61998', '5-906*01418*', '', '200', '', '', '0000-00-00', '2015-10-06', '', '0000-00-00', 1, 16),
	(25, 'ktm rc 200', 2015, 'BLACK', 'VBKJYC409FC006278', '', '5-906*01466*', '', '200', '', '', '0000-00-00', '2015-10-06', '', '0000-00-00', 1, 16),
	(26, 'Ducati Hyperstrada', 2014, 'RED', 'ML0B100AET001112', 'LC 54045', 'ZDM8214C-001114', '', '821', '', '', '0000-00-00', '2015-10-09', '', '0000-00-00', 7, 23),
	(27, 'DUCATI HYPERSTRADA', 2015, 'RED', 'ML0B100AAET001328', 'NONE', 'ZDM821W4C*001335', '', '821', '', '', '0000-00-00', '2015-10-10', '', '0000-00-00', 7, 92),
	(28, 'DUCATI 1198 SP', 2011, 'RED', 'ZDMH704AAAB029410', '5024 UP', 'ZDM1198WB*008136', '', '1198', '', '', '0000-00-00', '2015-10-13', '', '0000-00-00', 7, 23),
	(29, 'LX 150', 2013, 'LIGHT BROWN', 'RP8M66410DV012938', 'NA 36191', 'M668M21019333', '', '150', '', '', '0000-00-00', '2015-10-14', '', '0000-00-00', 5, 123),
	(30, 'LX 150', 2013, 'LIGHT BROWN', 'RP8M66410DV012938', 'NA 36191', 'M668M21019333', '', '150', '', '2015-10-14', '0000-00-00', '2015-10-14', '', '0000-00-00', 42, 0),
	(31, 'LX 150 ', 2014, 'LIGHT BLUE', 'RP8M66410DV012659', 'LC 16653', 'M6682018016', '', '150', '', '', '0000-00-00', '2015-10-15', '', '0000-00-00', 5, 125),
	(32, 'RC 200 NON-ABS', 2015, 'BLACK', 'VBKJYC401FC006260', '', '5-906*01405*', '', '200', '', '', '0000-00-00', '2015-10-16', '', '0000-00-00', 1, 83),
	(33, 'Italjet 125', 2015, 'Red/White', 'ZJTFRB8E8BL500221', '', 'LJIP52QMLI5013726', '', '125', '', '', '0000-00-00', '2015-10-20', '', '0000-00-00', 1, 83),
	(34, 'RC 200 NON-ABS ', 2015, 'BLACK', 'VBKJYC409FC006250', '', '5-906*10297*', '', '200', '', '', '0000-00-00', '2015-10-20', '', '0000-00-00', 1, 83),
	(35, 'Versys ', 2015, 'Lime Green ', 'LZT00B-006149', '', 'ZRT00DE089450', '', '1000', '', '', '0000-00-00', '2015-10-20', '', '0000-00-00', 30, 83),
	(36, 'Duke 200 Non-abs ', 2014, 'Orange', 'VBKJUC409EC020949', '', '4-906*52599*', '', '200', '', '', '0000-00-00', '2015-10-24', '', '0000-00-00', 1, 133),
	(37, 'KTM RC 390', 2015, 'WHITE', 'VBKJYJ0XFC210964', '', '5-902*06077', '', '390', '', '', '0000-00-00', '2015-10-27', '', '0000-00-00', 1, 83),
	(38, 'KTM RC 390', 2015, 'WHITE', 'VBKJYJ40XFC210964', '', '5-902*06077', '', '390', '', '', '0000-00-00', '2015-10-27', '', '0000-00-00', 1, 83),
	(39, 'KTM RC 390', 2015, 'WHITE', 'VBKJYJ401FC210965', '', '5-902*06109', '', '390', '', '', '0000-00-00', '2015-10-27', '', '0000-00-00', 1, 83),
	(40, 'Formula 125', 2015, 'Red/White ', 'ZJTFRB8E8BL500221', '', 'LJIP52QMI*15013726*', '', '125', '', '', '0000-00-00', '2015-11-06', '', '0000-00-00', 42, 137),
	(41, 'RC 390 ABS ', 2015, 'WHITE', 'VBKJYJ408FC210994', '', '5-902*06156*', '', '390', '', '', '0000-00-00', '2015-11-19', '', '0000-00-00', 1, 83),
	(42, 'RC 390 ABS ', 2015, 'WHITE', 'VBKJYJ408FC210994', '', '5-902*06156*', '', '390', '', '2015-11-19', '0000-00-00', '2015-11-19', '', '0000-00-00', 42, 141),
	(43, 'RC 200 NON-ABS', 2015, 'BLACK ', 'VBKJYC401FC006260', '', '5-906*01405*', '', '200', '', '', '0000-00-00', '2015-11-20', '', '0000-00-00', 1, 126),
	(44, 'RC 200 NON-ABS', 2015, 'BLACK ', 'VBKJYC401FC006260', '', '5-906*01405*', '', '200', '', '2015-11-20', '0000-00-00', '2015-11-20', '', '0000-00-00', 42, 142),
	(45, 'DUKE 200 NON-ABS', 2014, 'WHITE ', 'VBKJUC406EC027907', '', '4-906*58814*', '', '200', '', '', '0000-00-00', '2015-11-20', '', '0000-00-00', 1, 83),
	(46, 'MONSTER 795 ', 2014, 'RED', 'ML0M100AAET006824', '', 'ZDM796AC*006839*', '', '795', '', '', '0000-00-00', '2015-11-23', '', '0000-00-00', 7, 143),
	(47, 'Scrambler Icon ', 2015, 'Yellow', 'ML0K100AAFT00358', '', 'ML0800A2D000432', '', '805', '', '', '0000-00-00', '2015-11-23', '', '0000-00-00', 7, 83),
	(48, 'RC 200 NON-ABS ', 2015, 'Black', 'VBKJYC40XFC006273', '', '5-906*01457*', '', '200', '', '', '0000-00-00', '2015-11-24', '', '0000-00-00', 1, 83),
	(49, 'Italjet Formula 125', 2015, 'Red/White', 'ZJTFRBSE2BL500229', '', 'LJ1P52QMI*15013774*', '', '125', '', '', '0000-00-00', '2015-11-24', '', '0000-00-00', 42, 83),
	(50, 'DUKE 200 NON-ABS ', 2014, 'ORANGE', 'VBKJUC406EC023548', '', '4-906*54834*', '', '200', '', '', '0000-00-00', '2015-11-24', '', '0000-00-00', 1, 83),
	(51, 'Duke 200 Non-Abs ', 2014, 'Orange', 'VBKJUC409EC023656', '', '4-906*54818*', '', '200', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 0),
	(52, 'Duke 200 Non-Abs ', 2014, 'Orange', 'VBKJUC409EC023656', '', '4-906*54818*', '', '200', '', '2015-11-28', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 0),
	(53, 'Duke 200 Non-Abs ', 2014, 'Orange', 'VBKJUC409EC023656', '', '4-906*54818*', '', '200', '', '2015-11-28', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 0),
	(54, 'Duke 200 Non-abs ', 2014, 'White', 'VBKJUC408EC027696', '', '4-906*58276*', '', '200', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(55, 'Duke 200 Non-abs ', 2014, 'Orange ', 'VBKJUC403EC023555', '', '4-906*54931*', '', '200', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(56, 'Duke 390 Abs ', 2014, 'Black ', 'VBKJGJ407EC226928', '', '4-902*12929*', '', '390', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(57, 'Duke 390 Abs ', 2014, 'White ', 'VBKJGJ403EC231768', '', '4-902*17193*', '', '390', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(58, 'RC 200 Non-abs ', 2015, 'Black', 'VBKJYC404FC006284', '', '5-906*01546*', '', '200', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(59, 'RC 390 Abs ', 2015, 'White ', 'VBKJYJ403FC210983', '', '5-902*05964*', '', '390', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(60, 'Duke 200 Non-abs ', 2014, 'Orange ', 'VBKJUC409EC023656', '', '4-906*54818*', '', '200', '', '', '0000-00-00', '2015-11-28', '', '0000-00-00', 1, 83),
	(61, 'Duke 200 Non-abs', 2014, 'Orange', 'VBKJUC401EC009881', '', '4-906*41386*', '', '200', '', '', '0000-00-00', '2015-12-09', '', '0000-00-00', 1, 122),
	(62, 'Duke 390 Abs ', 2014, 'Black ', 'VBKJGJ400EC228231', '', '4-902*13135*', '', '390', '', '', '0000-00-00', '2015-12-16', '', '0000-00-00', 1, 153),
	(63, 'Duke 200 Non-abs ', 2014, 'Orange ', 'VBKJUC403EC013415', '', '4-906*44767*', '', '200', '', '', '0000-00-00', '2015-12-17', '', '0000-00-00', 1, 154),
	(64, 'Formula 125 ', 2015, 'Tricolore', 'ZJTFRBSE6BL500072', '', 'LJ1P52QMI*15000164*', '', '125', '', '', '0000-00-00', '2015-12-18', '', '0000-00-00', 42, 63),
	(65, 'Formula 125 ', 2015, 'Tricolore', 'ZJTFRBSE6BL500072', '', 'LJ1P52QMI*15000164*', '', '125', '', '2015-12-18', '0000-00-00', '2015-12-18', '', '0000-00-00', 42, 63),
	(66, 'Duke 390 Abs ', 2014, 'Black ', 'VBKJGJ400EC228231', 'NC 15111', '4-902*13135*', '', '390', '', '', '0000-00-00', '2015-12-18', '', '0000-00-00', 1, 153);
/*!40000 ALTER TABLE `tblcustomerbikes` ENABLE KEYS */;


-- Dumping structure for table invndc.tblcustomerservicing
DROP TABLE IF EXISTS `tblcustomerservicing`;
CREATE TABLE IF NOT EXISTS `tblcustomerservicing` (
  `idServicing` int(15) NOT NULL DEFAULT '0',
  `serviceNo` varchar(15) DEFAULT NULL,
  `idCustomer` int(8) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `barcode` varchar(255) DEFAULT NULL,
  `dateTrans` date DEFAULT NULL,
  `InCharge` int(10) DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`idServicing`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblcustomerservicing: 0 rows
/*!40000 ALTER TABLE `tblcustomerservicing` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblcustomerservicing` ENABLE KEYS */;


-- Dumping structure for table invndc.tbldeliveries
DROP TABLE IF EXISTS `tbldeliveries`;
CREATE TABLE IF NOT EXISTS `tbldeliveries` (
  `idDel` int(15) NOT NULL DEFAULT '0',
  `idOrder` int(15) DEFAULT NULL,
  `pk` int(15) DEFAULT NULL,
  `toBranch` varchar(25) DEFAULT NULL,
  `fromBranch` varchar(25) DEFAULT NULL,
  `poidBranch` varchar(16) DEFAULT NULL,
  `toInchrg` varchar(30) DEFAULT NULL,
  `toLctn` text,
  `rcptNo` varchar(15) DEFAULT NULL,
  `rcptBy` varchar(30) DEFAULT NULL,
  `termDel` varchar(15) DEFAULT NULL,
  `dateDue` date DEFAULT NULL,
  `invcNo` varchar(15) DEFAULT NULL,
  `docNo` varchar(15) DEFAULT '',
  `refNo` varchar(15) DEFAULT NULL,
  `soldTo` varchar(30) DEFAULT NULL,
  `totalQty` int(5) DEFAULT NULL,
  PRIMARY KEY (`idDel`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbldeliveries: 1 rows
/*!40000 ALTER TABLE `tbldeliveries` DISABLE KEYS */;
INSERT INTO `tbldeliveries` (`idDel`, `idOrder`, `pk`, `toBranch`, `fromBranch`, `poidBranch`, `toInchrg`, `toLctn`, `rcptNo`, `rcptBy`, `termDel`, `dateDue`, `invcNo`, `docNo`, `refNo`, `soldTo`, `totalQty`) VALUES
	(1, 1, 1, 'Norminring Motorbikes - C', 'Norminring Motorbikes - D', '1', 'Annie Rose M. Deloso', 'Davao City', '1', 'Ma. Cristina S. Pabelic', '15 days', '2015-03-12', '', '', '', 'Norminring Motorbikes - DVO', 10);
/*!40000 ALTER TABLE `tbldeliveries` ENABLE KEYS */;


-- Dumping structure for table invndc.tblempauth
DROP TABLE IF EXISTS `tblempauth`;
CREATE TABLE IF NOT EXISTS `tblempauth` (
  `id` int(10) NOT NULL,
  `idEmp` int(10) DEFAULT NULL,
  `userName` varchar(15) DEFAULT NULL,
  `passWord` char(50) DEFAULT NULL,
  `privilege` int(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblempauth: ~11 rows (approximately)
/*!40000 ALTER TABLE `tblempauth` DISABLE KEYS */;
INSERT INTO `tblempauth` (`id`, `idEmp`, `userName`, `passWord`, `privilege`) VALUES
	(1, 1000000001, 'amd', 'devadmin', 1),
	(2, 1000000001, 'amd', 'sales', 3),
	(3, 1000000003, 'jlj', 'jlj', 2),
	(4, 1000000005, 'csp', 'csp', 3),
	(5, 1000000008, 'dbb', 'kdjbb', 1),
	(6, 1000000011, 'lgb', '1235269', 1),
	(7, 1000000012, 'mca', 'mca1', 1),
	(8, 1000000006, 'jpd', 'jpd', 1),
	(9, 1000000013, 'iom', 'ilovesix', 3),
	(10, 1000000014, 'jvd', 'nonoy', 1),
	(11, 1000000015, 'ggt', 'ggt', 1),
	(12, 0, 'laq', 'laq', 4),
	(13, 1000000019, 'ivt', 'ivt', 1);
/*!40000 ALTER TABLE `tblempauth` ENABLE KEYS */;


-- Dumping structure for table invndc.tblemployee
DROP TABLE IF EXISTS `tblemployee`;
CREATE TABLE IF NOT EXISTS `tblemployee` (
  `idEmp` int(10) NOT NULL DEFAULT '0',
  `fName` varchar(25) DEFAULT NULL,
  `midInit` varchar(2) DEFAULT NULL,
  `lName` varchar(25) DEFAULT NULL,
  `idPosition` int(5) NOT NULL,
  `idCmpny` int(5) NOT NULL,
  `empStatus` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`idEmp`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblemployee: ~15 rows (approximately)
/*!40000 ALTER TABLE `tblemployee` DISABLE KEYS */;
INSERT INTO `tblemployee` (`idEmp`, `fName`, `midInit`, `lName`, `idPosition`, `idCmpny`, `empStatus`) VALUES
	(1000000001, 'Annie Rose', 'M', 'Deloso', 1, 5, ''),
	(1000000002, 'Janine', 'L', 'Jasmine', 2, 2, 'Regular'),
	(1000000003, 'Jan', 'L', 'Jasmin', 1, 3, 'Regular'),
	(1000000004, 'Herbert', 'F', 'Puyo II', 5, 2, 'Temporary'),
	(1000000005, 'Ma. Cristina', 'S', 'Pabelic', 2, 2, 'Regular'),
	(1000000006, 'Jennifer', 'P', 'Dantes', 6, 5, 'Permanent'),
	(1000000007, 'Jeffrey', 'M', 'Antique', 7, 2, 'Regular'),
	(1000000008, 'Darylle', 'B', 'Battad', 1, 2, 'Temporary'),
	(1000000009, 'Ivan', 'O', 'Paredes', 8, 2, 'Permanent'),
	(1000000010, 'Daniel', 'O', 'Fagela', 1, 2, 'Regular'),
	(1000000011, 'Lanz', 'G', 'Borromeo', 9, 3, 'Regular'),
	(1000000012, 'Marco', 'C', 'Arangco', 1, 1, 'Regular'),
	(1000000013, 'Irene', 'O', 'Mascarinas', 2, 2, 'Regular'),
	(1000000014, 'Joseph', 'V', 'Del Rosario Jr.', 12, 5, 'Regular'),
	(1000000015, 'Girlie', 'G', 'Tolosa', 5, 5, 'Regular'),
	(1000000016, 'Norben Jay', 'L', ' Ruiz', 10, 5, 'Regular'),
	(1000000017, 'Leo Alfie', 'A', 'Quipanes', 0, 5, 'Regular'),
	(1000000018, 'Jenner ', 'B', 'Moneba', 11, 4, 'Regular'),
	(1000000019, 'Iris ', 'V', 'Trinidad', 13, 5, 'Regular');
/*!40000 ALTER TABLE `tblemployee` ENABLE KEYS */;


-- Dumping structure for table invndc.tblempstatus
DROP TABLE IF EXISTS `tblempstatus`;
CREATE TABLE IF NOT EXISTS `tblempstatus` (
  `empStatus` varchar(50) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblempstatus: 3 rows
/*!40000 ALTER TABLE `tblempstatus` DISABLE KEYS */;
INSERT INTO `tblempstatus` (`empStatus`) VALUES
	('Regular'),
	('Resigned'),
	('On-Leave');
/*!40000 ALTER TABLE `tblempstatus` ENABLE KEYS */;


-- Dumping structure for table invndc.tblinsurance
DROP TABLE IF EXISTS `tblinsurance`;
CREATE TABLE IF NOT EXISTS `tblinsurance` (
  `insurance` varchar(20) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblinsurance: 3 rows
/*!40000 ALTER TABLE `tblinsurance` DISABLE KEYS */;
INSERT INTO `tblinsurance` (`insurance`) VALUES
	('Malayan'),
	('BPI'),
	('Others(specify)');
/*!40000 ALTER TABLE `tblinsurance` ENABLE KEYS */;


-- Dumping structure for table invndc.tblinventory
DROP TABLE IF EXISTS `tblinventory`;
CREATE TABLE IF NOT EXISTS `tblinventory` (
  `id` int(15) NOT NULL AUTO_INCREMENT,
  `code` int(11) DEFAULT NULL,
  `qtyBeg` int(11) DEFAULT NULL,
  `qtyIn` int(11) DEFAULT NULL,
  `qtyOut` int(11) DEFAULT NULL,
  `qtyEnd` int(11) DEFAULT NULL,
  `remarks` text,
  `dateInv` date DEFAULT NULL,
  `srp` double(15,2) DEFAULT NULL,
  `cost` double(15,2) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=1496 DEFAULT CHARSET=utf8;

-- Dumping data for table invndc.tblinventory: ~1,080 rows (approximately)
/*!40000 ALTER TABLE `tblinventory` DISABLE KEYS */;
INSERT INTO `tblinventory` (`id`, `code`, `qtyBeg`, `qtyIn`, `qtyOut`, `qtyEnd`, `remarks`, `dateInv`, `srp`, `cost`) VALUES
	(2, 2, 1, 0, 0, 1, 'Beginning', '2015-07-31', 759000.00, 0.00),
	(3, 3, 0, 0, 0, 0, 'Beginning', '2015-07-31', 550000.00, 0.00),
	(4, 4, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1199000.00, 447857.14),
	(5, 5, 0, 0, 0, 0, 'Beginning', '2015-07-31', 839000.00, 0.00),
	(6, 6, 1, 0, 1, 0, 'Sales', '2015-07-31', 839000.00, 0.00),
	(7, 7, 0, 0, 0, 0, 'Beginning', '2015-07-31', 839000.00, 0.00),
	(8, 8, 0, 0, 0, 0, 'Beginning', '2015-07-31', 570000.00, 0.00),
	(11, 11, 0, 0, 0, 0, 'Beginning', '2015-07-31', 450000.00, 0.00),
	(12, 12, 0, 0, 0, 0, 'Beginning', '2015-07-31', 599000.00, 0.00),
	(13, 13, 5, 1, 4, 2, 'Invoice 13', '2015-10-16', 199000.00, 0.00),
	(14, 14, 2, 1, 2, 1, 'Invoice 24', '2015-10-27', 399000.00, 0.00),
	(15, 15, 0, 0, 0, 0, 'Beginning', '2015-07-31', 178750.00, 178750.00),
	(16, 16, 0, 0, 0, 0, 'Beginning', '2015-07-31', 178750.00, 178750.00),
	(17, 17, 4, 0, 2, 2, 'Invoice 20', '2015-10-24', 159000.00, 0.00),
	(18, 18, 1, 0, 0, 1, 'Beginning', '2015-07-31', 0.00, 0.00),
	(19, 19, 0, 0, 0, 0, 'Beginning', '2015-07-31', 159000.00, 0.00),
	(20, 20, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(21, 21, 1, 0, 0, 1, 'Beginning', '2015-07-31', 0.00, 0.00),
	(22, 22, 11, 0, 3, 8, 'Sales', '2015-07-31', 299000.00, 0.00),
	(23, 23, 1, 0, 1, 0, 'Invoice 5', '2015-09-23', 620000.00, 0.00),
	(24, 24, 1, 0, 1, 0, 'Sales', '2015-07-31', 105000.00, 0.00),
	(25, 25, 0, 0, 0, 0, 'Beginning', '2015-07-31', 870000.00, 0.00),
	(26, 26, 1, 0, 0, 1, 'Beginning', '2015-07-31', 229000.00, 0.00),
	(27, 27, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(28, 28, 0, 0, 0, 0, 'Beginning', '2015-07-31', 249000.00, 0.00),
	(29, 29, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(30, 30, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 79553.57),
	(31, 31, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 79553.57),
	(33, 33, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 285714.29),
	(36, 36, 2, 0, 0, 2, 'Beginning', '2015-07-31', 10765.00, 0.00),
	(37, 37, 0, 0, 0, 0, 'Beginning', '2015-07-31', 6900.00, 0.00),
	(38, 38, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2545.00, 0.00),
	(39, 39, 1, 0, 0, 1, 'Beginning', '2015-07-31', 15876.00, 8775.00),
	(40, 40, 1, 0, 0, 1, 'Beginning', '2015-07-31', 72474.00, 43140.18),
	(41, 41, 1, 0, 0, 1, 'Beginning', '2015-07-31', 12372.00, 7180.36),
	(42, 42, 1, 0, 0, 1, 'Beginning', '2015-07-31', 11010.00, 6881.25),
	(43, 43, 1, 0, 0, 1, 'Beginning', '2015-07-31', 11520.00, 6604.46),
	(44, 44, 1, 0, 0, 1, 'Beginning', '2015-07-31', 11520.00, 6369.64),
	(45, 45, 1, 0, 0, 1, 'Beginning', '2015-07-31', 10158.00, 6720.54),
	(47, 47, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3701.79),
	(48, 48, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 654.64),
	(49, 49, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 990.18),
	(50, 50, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 614.29),
	(51, 51, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 843.75),
	(52, 52, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 614.29),
	(53, 53, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 28674.11),
	(54, 54, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11889.29),
	(55, 55, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 337.50),
	(56, 56, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 975.00),
	(58, 58, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2406.25),
	(60, 60, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1950.90),
	(61, 61, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 944.65),
	(63, 63, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8100.00),
	(64, 64, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 192.86),
	(65, 65, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7488.39),
	(66, 66, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5903.57),
	(67, 67, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5562.00, 2980.36),
	(69, 69, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4611.61),
	(70, 70, 1, 0, 0, 1, 'Beginning', '2015-07-31', 8930.00, 4468.36),
	(71, 71, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5225.00, 2627.32),
	(72, 72, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2668.75),
	(73, 73, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1853.57),
	(74, 74, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9325.00, 4501.98),
	(75, 75, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3921.43),
	(77, 77, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1373.21),
	(78, 78, 2, 0, 0, 2, 'Beginning', '2015-07-31', 3055.00, 1475.89),
	(79, 79, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3837.22),
	(80, 80, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1219.82),
	(81, 81, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1102.82),
	(82, 82, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 16.07),
	(83, 83, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 39.29),
	(84, 84, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 180.36),
	(85, 85, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2175.00),
	(86, 86, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6342.86),
	(87, 87, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 10293.75),
	(88, 88, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 132.15),
	(89, 89, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11543.75),
	(90, 90, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12303.57),
	(91, 91, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8002.68),
	(92, 92, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3716.07),
	(93, 93, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 30364.29),
	(94, 94, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 433.04),
	(95, 95, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 13283.04),
	(96, 96, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5280.36),
	(97, 97, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6881.25),
	(98, 98, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 13283.04),
	(99, 99, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5602.68),
	(100, 100, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 218.39),
	(101, 101, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 13668.75),
	(102, 102, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 13815.18),
	(103, 103, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3055.00, 0.00),
	(104, 104, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(105, 105, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 10443.75),
	(106, 106, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 43467.86),
	(107, 107, 0, 0, 0, 0, 'Beginning', '2015-07-31', 504.00, 0.00),
	(108, 108, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4594.64),
	(109, 109, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3464.29),
	(110, 110, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3602.68),
	(111, 111, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3726.00, 1169.64),
	(112, 112, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5250.89),
	(113, 113, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3414.29),
	(114, 114, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4275.00),
	(115, 115, 1, 0, 0, 1, 'Beginning', '2015-07-31', 8490.00, 5514.29),
	(116, 116, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3132.23),
	(117, 117, 1, 0, 0, 1, 'Beginning', '2015-07-31', 10059.00, 4320.62),
	(118, 118, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5514.29),
	(119, 119, 1, 0, 0, 1, 'Beginning', '2015-07-31', 7719.00, 5514.29),
	(120, 120, 1, 0, 0, 1, 'Beginning', '2015-07-31', 10059.00, 4320.62),
	(121, 121, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3400.00),
	(122, 122, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5514.29),
	(123, 123, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3744.64),
	(124, 124, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3381.25),
	(125, 125, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4591.97),
	(126, 126, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3992.00, 2139.29),
	(127, 127, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3645.95),
	(128, 128, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2522.32),
	(129, 129, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4818.75),
	(130, 130, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4348.21),
	(131, 131, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1483.93),
	(132, 132, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 629.47),
	(133, 133, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1200.89),
	(134, 134, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1200.90),
	(135, 135, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6056.25),
	(136, 136, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2712.50),
	(137, 137, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1595.00, 0.00),
	(138, 138, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3300.00, 0.00),
	(139, 139, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3738.39),
	(140, 140, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3596.43),
	(141, 141, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3596.43),
	(142, 142, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3596.43),
	(143, 143, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5298.21),
	(144, 144, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5298.21),
	(145, 145, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3596.43),
	(146, 146, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3250.00),
	(147, 147, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3250.00),
	(148, 148, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12750.00),
	(149, 149, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8678.57),
	(150, 150, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1114.29),
	(151, 151, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7417.86),
	(152, 152, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 155.36),
	(153, 153, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1732.14),
	(154, 154, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5.36),
	(155, 155, 4, 0, 3, 1, 'sold', '2015-11-23', 1130.00, 503.00),
	(156, 156, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2883.04),
	(157, 157, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3340.18),
	(158, 158, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3253.57),
	(159, 159, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3340.18),
	(160, 160, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 10.71),
	(161, 161, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 133.93),
	(162, 162, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 311.61),
	(163, 163, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6348.21),
	(164, 164, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6343.75),
	(165, 165, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7620.54),
	(166, 166, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11400.00),
	(167, 167, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11430.36),
	(168, 168, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7678.57),
	(169, 169, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5455.36),
	(170, 170, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4596.96),
	(171, 171, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3633.93),
	(172, 172, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 198.21),
	(173, 173, 0, 0, 0, 0, 'Beginning', '2015-07-31', 504.00, 0.00),
	(174, 174, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1028.57),
	(175, 175, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 101.79),
	(176, 176, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 185.71),
	(177, 177, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 198.21),
	(178, 178, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7.14),
	(179, 179, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 75.00),
	(180, 180, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 591.97),
	(181, 181, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 10.72),
	(182, 182, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 326.79),
	(183, 183, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9398.21),
	(184, 184, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9165.18),
	(185, 185, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 10614.29),
	(186, 186, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4247.32),
	(187, 187, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1939.29),
	(188, 188, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 67481.25),
	(189, 189, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 691.07),
	(190, 190, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 691.07),
	(191, 191, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4526.79),
	(194, 194, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1861.61),
	(196, 196, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1237.50),
	(197, 197, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1237.50),
	(198, 198, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1861.61),
	(203, 203, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1145.54),
	(204, 204, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1145.54),
	(205, 205, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 37.50),
	(206, 206, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1133.04),
	(207, 207, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 297.11),
	(208, 208, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 297.11),
	(211, 211, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1045.54),
	(212, 212, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(213, 213, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 250.00),
	(214, 214, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1117.93),
	(215, 215, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 297.11),
	(216, 216, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1215.50, 0.00),
	(284, 284, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4755.00, 2750.00),
	(285, 285, 0, 4, 0, 4, 'Received', '2015-07-31', 4755.00, 2750.00),
	(286, 286, 0, 2, 0, 2, 'Received', '2015-07-31', 2885.00, 1669.50),
	(287, 287, 0, 1, 0, 1, 'Beginning', '2015-07-31', 12595.00, 7300.00),
	(288, 288, 0, 3, 0, 3, 'Received', '2015-07-31', 3520.00, 2035.00),
	(289, 289, 0, 1, 0, 1, 'Received', '2015-07-31', 4180.00, 0.00),
	(290, 290, 0, 0, 0, 0, 'Beginning', '2015-07-31', 37000.00, 0.00),
	(291, 291, 2, 0, 1, 1, 'sold', '2015-12-19', 6400.00, 4130.00),
	(292, 292, 1, 0, 0, 1, 'Beginning', '2015-07-31', 14665.00, 8500.00),
	(293, 293, 0, 0, 0, 0, 'Beginning', '2015-07-31', 7420.00, 0.00),
	(294, 294, 0, 0, 0, 0, 'Beginning', '2015-07-31', 13530.00, 0.00),
	(295, 295, 3, 0, 0, 3, 'Beginning', '2015-07-31', 2145.00, 1225.00),
	(296, 296, 1, 0, 0, 1, 'Beginning', '2015-07-31', 520.00, 295.00),
	(297, 297, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3080.00, 0.00),
	(298, 298, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3080.00, 0.00),
	(299, 299, 0, 0, 0, 0, 'Beginning', '2015-07-31', 24750.00, 19800.00),
	(300, 300, 0, 0, 0, 0, 'Beginning', '2015-07-31', 25480.00, 18200.00),
	(301, 301, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1400.00, 0.00),
	(302, 302, 0, 0, 0, 0, 'Beginning', '2015-07-31', 14200.00, 0.00),
	(303, 303, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1500.00, 1020.00),
	(304, 304, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2640.00, 0.00),
	(305, 305, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2090.00, 0.00),
	(306, 306, 2, 1, 0, 3, 'Received', '2015-07-31', 4400.00, 2415.00),
	(307, 307, 11, 0, 1, 10, 'sold', '2015-09-11', 4400.00, 2415.00),
	(308, 308, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2420.00, 0.00),
	(309, 309, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2420.00, 0.00),
	(310, 310, 1, 5, 0, 6, 'Received', '2015-07-31', 1115.00, 644.00),
	(311, 311, 1, 5, 0, 6, 'Received', '2015-07-31', 2055.00, 1085.00),
	(312, 312, 0, 2, 0, 2, 'Received', '2015-07-31', 2055.00, 1085.00),
	(313, 313, 0, 5, 0, 5, 'Received', '2015-07-31', 2055.00, 1085.00),
	(314, 314, 3, 0, 3, 0, 'sold', '2015-12-09', 2420.00, 1382.50),
	(315, 315, 2, 0, 0, 2, 'Beginning', '2015-07-31', 2420.00, 1382.50),
	(316, 316, 2, 0, 0, 2, 'Beginning', '2015-07-31', 1540.00, 0.00),
	(317, 317, 0, 5, 0, 5, 'Received', '2015-07-31', 520.00, 295.00),
	(318, 318, 2, 1, 0, 3, 'Received', '2015-07-31', 730.00, 385.00),
	(319, 319, 1, 1, 0, 2, 'Received', '2015-07-31', 730.00, 385.00),
	(320, 320, 3, 0, 0, 3, 'Beginning', '2015-07-31', 1320.00, 0.00),
	(321, 321, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1190.00, 0.00),
	(322, 322, 2, 0, 0, 2, 'Beginning', '2015-07-31', 4394.50, 803.57),
	(324, 324, 2, 0, 0, 2, 'Beginning', '2015-07-31', 3280.00, 0.00),
	(325, 325, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2520.00, 0.00),
	(326, 326, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2520.00, 0.00),
	(327, 327, 3, 0, 0, 3, 'Beginning', '2015-07-31', 4115.00, 2275.00),
	(329, 329, 11, 0, 1, 10, 'sold2015-68', '2015-11-23', 4125.00, 2275.00),
	(331, 331, 1, 0, 1, 0, 'sold', '2015-10-10', 4125.00, 0.00),
	(332, 332, 7, 0, 0, 7, 'Beginning', '2015-07-31', 1335.00, 700.00),
	(333, 333, 3, 0, 0, 3, 'Beginning', '2015-07-31', 5040.00, 2920.00),
	(334, 334, 6, 0, 2, 4, 'sold', '2015-12-17', 5040.00, 2920.00),
	(335, 335, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5040.00, 0.00),
	(336, 336, 1, 0, 0, 1, 'Beginning', '2015-07-31', 7590.00, 0.00),
	(337, 337, 3, 0, 0, 3, 'Beginning', '2015-07-31', 7755.00, 0.00),
	(338, 338, 5, 0, 0, 5, 'Beginning', '2015-07-31', 7755.00, 0.00),
	(339, 339, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4478.00, 2799.11),
	(340, 340, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3017.86),
	(341, 341, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1566.97),
	(342, 342, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1607.14),
	(343, 343, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3500.00),
	(344, 344, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2571.43),
	(345, 345, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1191.22),
	(346, 346, 2, 0, 0, 2, 'Beginning', '2015-07-31', 1870.00, 910.71),
	(347, 347, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 571.43),
	(348, 348, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2553.57),
	(349, 349, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2400.00),
	(350, 350, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1928.57),
	(351, 351, 5, 0, 1, 4, 'sold', '2015-11-27', 1430.00, 642.86),
	(352, 352, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 830.36),
	(353, 353, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12285.71),
	(354, 354, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1276.79),
	(355, 355, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1946.43),
	(356, 356, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1857.14),
	(357, 357, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(358, 358, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4514.29),
	(359, 359, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3600.00, 0.00),
	(361, 361, 3, 0, 2, 1, 'sold', '2015-09-12', 2090.00, 830.36),
	(362, 362, 3, 0, 0, 3, 'Beginning', '2015-07-31', 8580.00, 5223.21),
	(363, 363, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2741.96),
	(364, 364, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3000.00),
	(365, 365, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 696.43),
	(366, 366, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 750.00),
	(367, 367, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(368, 368, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1092.86),
	(369, 369, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5517.86),
	(370, 370, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(372, 372, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 535.72),
	(373, 373, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 257.14),
	(374, 374, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 522.32),
	(375, 375, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 369.90),
	(376, 376, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2437.50),
	(377, 377, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.72),
	(378, 378, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12803.57),
	(379, 379, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3107.15),
	(380, 380, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 642.86),
	(381, 381, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1392.86),
	(382, 382, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1937.50),
	(383, 383, 2, 0, 0, 2, 'Beginning', '2015-07-31', 6515.00, 0.00),
	(384, 384, 3, 0, 0, 3, 'Beginning', '2015-07-31', 3400.00, 2216.07),
	(385, 385, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(386, 386, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2075.89),
	(387, 387, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2075.89),
	(388, 388, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1221.43),
	(389, 389, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 787.50),
	(390, 390, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 910.71),
	(391, 391, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(392, 392, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(393, 393, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3075.89),
	(394, 394, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12000.00),
	(395, 395, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12000.00),
	(397, 397, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4745.54),
	(398, 398, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(399, 399, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 321.43),
	(400, 400, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1607.14),
	(401, 401, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(402, 402, 2, 0, 0, 2, 'Beginning', '2015-07-31', 14850.00, 9040.18),
	(403, 403, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(404, 404, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 14000.00),
	(405, 405, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1339.29),
	(406, 406, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(407, 407, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 696.43),
	(408, 408, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.14),
	(409, 409, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 14571.43),
	(410, 410, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.72),
	(411, 411, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 642.86),
	(412, 412, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(413, 413, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(414, 414, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(415, 415, 0, 1, 1, 0, 'sold', '2015-11-27', 1430.00, 807.14),
	(416, 416, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(417, 417, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4660.72),
	(418, 418, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1240.00, 0.00),
	(419, 419, 0, 0, 0, 0, 'Beginning', '2015-07-31', 14350.00, 0.00),
	(420, 420, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5440.00, 0.00),
	(421, 421, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(422, 422, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1125.00),
	(423, 423, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2185.72),
	(424, 424, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2678.57),
	(425, 425, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1392.86),
	(426, 426, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5687.50),
	(427, 427, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(428, 428, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1125.00),
	(429, 429, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3562.50),
	(430, 430, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4071.43),
	(431, 431, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2892.86),
	(432, 432, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6897.32),
	(433, 433, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4071.43),
	(434, 434, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 482.15),
	(435, 435, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 482.15),
	(436, 436, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 482.15),
	(437, 437, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 482.15),
	(438, 438, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(439, 439, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(440, 440, 4, 0, 0, 4, 'Beginning', '2015-07-31', 1320.00, 589.29),
	(441, 441, 2, 1, 2, 1, 'sold', '2015-11-11', 825.00, 535.71),
	(442, 442, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(443, 443, 1, 5, 0, 6, 'Received', '2015-07-31', 1115.00, 647.00),
	(444, 444, 2, 0, 0, 2, 'Beginning', '2015-07-31', 1210.00, 0.00),
	(445, 445, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(446, 446, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8464.29),
	(447, 447, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(448, 448, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5195.00, 0.00),
	(449, 449, 3, 0, 0, 3, 'Beginning', '2015-07-31', 990.00, 428.57),
	(450, 450, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2167.86),
	(451, 451, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(452, 452, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5500.00),
	(453, 453, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(454, 454, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5303.57),
	(455, 455, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12129.47),
	(456, 456, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 321.43),
	(457, 457, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(458, 458, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 964.29),
	(459, 459, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 910.72),
	(460, 460, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5049.11),
	(461, 461, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(462, 462, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(463, 463, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(464, 464, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4928.57),
	(465, 465, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 910.71),
	(466, 466, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(467, 467, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 986.61),
	(468, 468, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 321.43),
	(469, 469, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1000.00),
	(471, 471, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2250.00),
	(472, 472, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 522.32),
	(473, 473, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4920.00, 3050.40),
	(474, 474, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3000.00),
	(475, 475, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1856.92),
	(476, 476, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3857.14),
	(477, 477, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(478, 478, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2678.57),
	(479, 479, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(480, 480, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2410.71),
	(481, 481, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3191.96),
	(482, 482, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(483, 483, 0, 0, 0, 0, 'Beginning', '2015-07-31', 23145.00, 0.00),
	(485, 485, 2, 0, 0, 2, 'Beginning', '2015-07-31', 550.00, 267.86),
	(486, 486, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(487, 487, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1100.00, 580.36),
	(488, 488, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4392.86),
	(490, 490, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1660.71),
	(491, 491, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2862.50),
	(492, 492, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1607.14),
	(493, 493, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2305.36),
	(494, 494, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1645.54),
	(495, 495, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3630.00, 1767.86),
	(496, 496, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1607.14),
	(497, 497, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(498, 498, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2410.72),
	(499, 499, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4110.00, 1251.79),
	(500, 500, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2400.00, 1251.79),
	(501, 501, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3803.57),
	(502, 502, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3214.29),
	(503, 503, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(504, 504, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2496.43),
	(505, 505, 0, 0, 0, 0, 'Beginning', '2015-07-31', 6680.00, 4141.60),
	(506, 506, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2196.43),
	(507, 507, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2100.00, 0.00),
	(508, 508, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1980.00, 964.29),
	(509, 509, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3000.00),
	(510, 510, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1571.43),
	(511, 511, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8785.72),
	(512, 512, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 910.71),
	(513, 513, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 910.72),
	(514, 514, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2785.72),
	(515, 515, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1017.86),
	(516, 516, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1017.86),
	(517, 517, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1339.29),
	(518, 518, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1767.86),
	(519, 519, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(520, 520, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(521, 521, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3812.50),
	(522, 522, 3, 0, 0, 3, 'Beginning', '2015-07-31', 700.00, 313.01),
	(523, 523, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 375.00),
	(525, 525, 1, 0, 1, 0, 'Sales', '2015-07-31', 660.00, 321.43),
	(526, 526, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 400.89),
	(527, 527, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 263.37),
	(528, 528, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 271.43),
	(529, 529, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 562.50),
	(530, 530, 0, 2, 1, 1, 'sold', '2015-11-11', 1100.00, 535.72),
	(531, 531, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 776.79),
	(532, 532, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 696.43),
	(533, 533, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.72),
	(534, 534, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 642.86),
	(535, 535, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 114.80),
	(536, 536, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1687.50),
	(537, 537, 28, 0, 13, 15, 'sold2015-70', '2015-12-01', 660.00, 295.00),
	(538, 538, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(539, 539, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 71.43),
	(540, 540, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(541, 541, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4062.50),
	(542, 542, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3589.29),
	(543, 543, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2031.25),
	(544, 544, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2031.25),
	(545, 545, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(546, 546, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1232.14),
	(547, 547, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1232.14),
	(548, 548, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(549, 549, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1821.43),
	(550, 550, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 535.71),
	(551, 551, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1821.43),
	(552, 552, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1285.71),
	(553, 553, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1017.86),
	(554, 554, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7125.00),
	(555, 555, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6714.29),
	(556, 556, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8830.36),
	(557, 557, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 848.21),
	(558, 558, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(559, 559, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2687.50),
	(560, 560, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1272.32),
	(561, 561, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2100.00, 1302.00),
	(562, 562, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2970.00, 1841.40),
	(563, 563, 0, 0, 0, 0, 'Beginning', '2015-07-31', 14810.00, 0.00),
	(564, 564, 1, 0, 0, 1, 'Beginning', '2015-07-31', 30900.00, 0.00),
	(565, 565, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2147.32),
	(566, 566, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5195.00, 0.00),
	(567, 567, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 10125.00),
	(568, 568, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5745.54),
	(569, 569, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3910.72),
	(570, 570, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2274.11),
	(571, 571, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5100.90),
	(572, 572, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3053.57),
	(573, 573, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2447.32),
	(574, 574, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2108.04),
	(575, 575, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(576, 576, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 857.14),
	(577, 577, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2025.00),
	(578, 578, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1888.10),
	(579, 579, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1031.25),
	(580, 580, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2437.50),
	(581, 581, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2263.40),
	(582, 582, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 375.00),
	(583, 583, 0, 3, 0, 3, 'received 2015-12', '2015-10-03', 6010.00, 3899.99),
	(584, 584, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1017.86),
	(585, 585, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2089.29),
	(586, 586, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 468.75),
	(587, 587, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(588, 588, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(589, 589, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1875.00),
	(590, 590, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.14),
	(591, 591, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 192.86),
	(592, 592, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1017.86),
	(593, 593, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(594, 594, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 160.71),
	(595, 595, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(596, 596, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(597, 597, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 174.11),
	(598, 598, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.15),
	(599, 599, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.14),
	(600, 600, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 53.57),
	(601, 601, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.14),
	(602, 602, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1647.32),
	(603, 603, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 321.43),
	(604, 604, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(605, 605, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(606, 606, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 321.43),
	(607, 607, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 375.00),
	(608, 608, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.14),
	(609, 609, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 107.14),
	(610, 610, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 375.00),
	(611, 611, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 321.43),
	(612, 612, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 348.21),
	(613, 613, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 16071.43),
	(614, 614, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(615, 615, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(616, 616, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(617, 617, 0, 1, 1, 0, 'Sales', '2015-07-31', 2905.00, 1414.29),
	(618, 618, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1414.29),
	(620, 620, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1414.29),
	(621, 621, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(622, 622, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 46285.71),
	(623, 623, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(624, 624, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11250.00),
	(625, 625, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3321.43),
	(626, 626, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1553.57),
	(627, 627, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(628, 628, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 267.86),
	(629, 629, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 214.29),
	(630, 630, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 857.14),
	(631, 631, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 589.29),
	(632, 632, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 714.29),
	(633, 633, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1265.00, 730.00),
	(634, 634, 2, 0, 0, 2, 'Beginning', '2015-07-31', 990.00, 580.36),
	(635, 635, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 468.75),
	(636, 636, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(637, 637, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1735.00, 1004.46),
	(638, 638, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 482.14),
	(639, 639, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1044.64),
	(640, 640, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1071.43),
	(641, 641, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(642, 642, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(643, 643, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1250.00),
	(644, 644, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1250.00),
	(645, 645, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 482.14),
	(646, 646, 4, 0, 0, 4, 'Beginning', '2015-07-31', 3740.00, 2386.61),
	(647, 647, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 562.50),
	(648, 648, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2025.00),
	(649, 649, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2428.57),
	(650, 650, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4446.43),
	(651, 651, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1360.00, 843.20),
	(652, 652, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2428.57),
	(653, 653, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1406.25),
	(654, 654, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1312.50),
	(655, 655, 3, 0, 0, 3, 'Beginning', '2015-07-31', 2310.00, 867.86),
	(697, 697, 2, 0, 0, 2, 'Beginning', '2015-07-31', 865.00, 0.00),
	(698, 698, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2035.00, 0.00),
	(699, 699, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1345.00, 0.00),
	(725, 725, 7, 0, 2, 5, 'sold2015-72', '2015-12-03', 180.00, 0.00),
	(726, 726, 18, 0, 13, 5, 'sold2015-70', '2015-12-01', 55.00, 15.00),
	(727, 727, 8, 0, 0, 8, 'Beginning', '2015-07-31', 110.00, 15.00),
	(728, 728, 1, 0, 0, 1, 'Beginning', '2015-07-31', 385.00, 285.00),
	(729, 729, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1650.00, 900.00),
	(730, 730, 1, 0, 1, 0, 'Sales', '2015-07-31', 1650.00, 900.00),
	(731, 731, 1, 0, 0, 1, 'Beginning', '2015-07-31', 330.00, 130.90),
	(732, 732, 46, 0, 0, 46, 'Beginning', '2015-07-31', 330.00, 130.90),
	(733, 733, 15, 0, 0, 15, 'Beginning', '2015-07-31', 330.00, 130.90),
	(734, 734, 14, 0, 0, 14, 'Beginning', '2015-07-31', 330.00, 140.90),
	(735, 735, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5500.00, 0.00),
	(736, 736, 0, 0, 0, 0, 'Beginning', '2015-07-31', 10500.00, 0.00),
	(737, 737, 2, 0, 0, 2, 'Beginning', '2015-07-31', 3135.00, 0.00),
	(738, 738, 1, 0, 0, 1, 'Beginning', '2015-07-31', 16200.00, 8571.43),
	(739, 739, 1, 0, 0, 1, 'Beginning', '2015-07-31', 16200.00, 8571.43),
	(740, 740, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8571.43),
	(741, 741, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 42.41),
	(742, 742, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 22.32),
	(743, 743, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11.16),
	(744, 744, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3455.36),
	(745, 745, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6071.43),
	(746, 746, 0, 0, 0, 0, 'Beginning', '2015-07-31', 480.00, 0.00),
	(747, 747, 2, 0, 0, 2, 'Beginning', '2015-07-31', 5600.00, 4000.00),
	(748, 748, 0, 0, 0, 0, 'Beginning', '2015-07-31', 8500.00, 0.00),
	(749, 749, 0, 0, 0, 0, 'Beginning', '2015-07-31', 550.00, 0.00),
	(750, 750, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(751, 751, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(752, 752, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(753, 753, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2500.00),
	(754, 754, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1500.00),
	(755, 755, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5500.00, 0.00),
	(756, 756, 2, 0, 1, 1, 'Sales', '2015-07-31', 250.00, 100.00),
	(757, 757, 6, 0, 0, 6, 'Beginning', '2015-07-31', 400.00, 0.00),
	(758, 758, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 803.57),
	(759, 759, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 33.48),
	(760, 760, 0, 0, 0, 0, 'Beginning', '2015-07-31', 605.00, 0.00),
	(761, 761, 0, 0, 0, 0, 'Beginning', '2015-07-31', 605.00, 0.00),
	(762, 762, 3, 0, 0, 3, 'Beginning', '2015-07-31', 560.00, 0.00),
	(763, 763, 4, 0, 0, 4, 'Beginning', '2015-07-31', 805.00, 0.00),
	(764, 764, 3, 0, 1, 2, 'sold', '2015-10-15', 555.00, 0.00),
	(765, 765, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2142.86),
	(766, 766, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(767, 767, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2850.00, 0.00),
	(768, 768, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1687.50),
	(769, 769, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1400.00),
	(770, 770, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2250.00),
	(771, 771, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3850.00, 0.00),
	(772, 772, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4500.00, 0.00),
	(773, 773, 1, 0, 0, 1, 'Beginning', '2015-07-31', 836.00, 482.14),
	(774, 774, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 602.68),
	(775, 775, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3.38),
	(776, 776, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5.63),
	(777, 777, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7.31),
	(778, 778, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 27.50),
	(779, 779, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12.86),
	(780, 780, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7.86),
	(781, 781, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.83),
	(782, 782, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6800.00),
	(783, 783, 0, 0, 0, 0, 'Beginning', '2015-07-31', 30800.00, 0.00),
	(784, 784, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11.90),
	(785, 785, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9.82),
	(786, 786, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5.36),
	(787, 787, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5236.61),
	(788, 788, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3977.68),
	(789, 789, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(790, 790, 0, 1, 1, 0, 'sold2015-62', '2015-11-11', 550.00, 128.53),
	(791, 791, 0, 1, 0, 1, 'Received', '2015-07-31', 550.00, 128.53),
	(792, 792, 0, 0, 0, 0, 'Beginning', '2015-07-31', 605.00, 0.00),
	(793, 793, 2, 0, 2, 0, 'Sales', '2015-07-31', 250.00, 100.00),
	(794, 794, 0, 0, 0, 0, 'Beginning', '2015-07-31', 400.00, 145.85),
	(795, 795, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 232.15),
	(796, 796, 1, 0, 1, 0, 'Sales', '2015-07-31', 550.00, 145.85),
	(797, 797, 1, 0, 1, 0, 'Sales', '2015-07-31', 550.00, 145.85),
	(798, 798, 3, 0, 1, 2, 'Sales', '2015-07-31', 135.00, 80.00),
	(799, 799, 8, 6, 10, 4, 'sold', '2015-11-28', 135.00, 0.00),
	(800, 800, 2, 0, 0, 2, 'Beginning', '2015-07-31', 0.00, 0.00),
	(801, 801, 1, 0, 0, 1, 'Beginning', '2015-07-31', 135.00, 80.00),
	(802, 802, 3, 0, 0, 3, 'Beginning', '2015-07-31', 250.00, 100.00),
	(803, 803, 3, 0, 0, 3, 'Beginning', '2015-07-31', 550.00, 150.00),
	(804, 804, 0, 0, 0, 0, 'Beginning', '2015-07-31', 550.00, 150.00),
	(805, 805, 0, 0, 0, 0, 'Beginning', '2015-07-31', 550.00, 150.00),
	(806, 806, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(807, 807, 0, 2, 2, 0, 'sold2015-54', '2015-10-26', 550.00, 145.85),
	(808, 808, 1, 0, 1, 0, 'Sales', '2015-07-31', 605.00, 0.00),
	(809, 809, 1, 0, 1, 0, 'sold', '2015-09-01', 605.00, 0.00),
	(810, 810, 1, 0, 1, 0, 'sold2015-54', '2015-10-26', 605.00, 0.00),
	(811, 811, 195, 0, 14, 181, 'sold2015-69', '2015-11-28', 110.00, 0.00),
	(812, 812, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(813, 813, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3455.00, 0.00),
	(814, 814, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 602.68),
	(815, 815, 0, 0, 0, 0, 'Beginning', '2015-07-31', 902.00, 522.32),
	(817, 817, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 522.32),
	(818, 818, 2, 0, 0, 2, 'Beginning', '2015-07-31', 975.00, 0.00),
	(819, 819, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1100.00, 562.50),
	(820, 820, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 361.61),
	(821, 821, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 13.39),
	(822, 822, 0, 0, 0, 0, 'Beginning', '2015-07-31', 25685.00, 6500.00),
	(823, 823, 0, 0, 0, 0, 'Beginning', '2015-07-31', 41500.00, 0.00),
	(824, 824, 5, 0, 0, 5, 'Beginning', '2015-07-31', 11200.00, 6500.00),
	(825, 825, 2, 0, 0, 2, 'Beginning', '2015-07-31', 5060.00, 0.00),
	(826, 826, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5940.00, 0.00),
	(827, 827, 1, 0, 0, 1, 'Beginning', '2015-07-31', 10970.00, 0.00),
	(828, 828, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3635.00, 2290.18),
	(829, 829, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2465.00, 0.00),
	(830, 830, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9565.00, 0.00),
	(831, 831, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3610.00, 0.00),
	(832, 832, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3610.00, 0.00),
	(833, 833, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4095.00, 0.00),
	(834, 834, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1571.43),
	(835, 835, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1607.14),
	(836, 836, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4642.86),
	(837, 837, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2500.00, 0.00),
	(838, 838, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(839, 839, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1919.65),
	(840, 840, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1155.00, 0.00),
	(841, 841, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3928.57),
	(842, 842, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3928.57),
	(843, 843, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3142.86),
	(844, 844, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3142.86),
	(845, 845, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6428.57),
	(846, 846, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6428.57),
	(847, 847, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2000.00, 0.00),
	(848, 848, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1680.00, 0.00),
	(849, 849, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5445.00, 0.00),
	(850, 850, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7571.43),
	(851, 851, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2000.00, 0.00),
	(852, 852, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 178.57),
	(853, 853, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 178.57),
	(854, 854, 2, 0, 1, 1, 'sold', '2015-12-17', 5445.00, 0.00),
	(855, 855, 0, 0, 0, 0, 'Beginning', '2015-07-31', 6380.00, 0.00),
	(857, 857, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4000.00, 0.00),
	(858, 858, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4000.00, 0.00),
	(859, 859, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 441.96),
	(860, 860, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 312.50),
	(861, 861, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 312.50),
	(862, 862, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 178.57),
	(863, 863, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 714.29),
	(864, 864, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 178.57),
	(865, 865, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 176.79),
	(866, 866, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1100.00),
	(867, 867, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 225.00),
	(868, 868, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(869, 869, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 178.57),
	(870, 870, 1, 0, 0, 1, 'Beginning', '2015-07-31', 6560.00, 0.00),
	(871, 871, 1, 0, 0, 1, 'Beginning', '2015-07-31', 6560.00, 0.00),
	(872, 872, 11, 0, 1, 10, 'sold2015-61', '2015-11-10', 150.00, 35.71),
	(873, 873, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(874, 874, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(875, 875, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(876, 876, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3135.00, 1710.00),
	(877, 877, 200, 0, 0, 200, 'Beginning', '2015-07-31', 120.00, 35.71),
	(878, 878, 120, 0, 0, 120, 'Beginning', '2015-07-31', 550.00, 178.57),
	(879, 879, 197, 0, 0, 197, 'Beginning', '2015-07-31', 120.00, 35.71),
	(880, 880, 0, 0, 0, 0, 'Beginning', '2015-07-31', 120.00, 35.71),
	(881, 881, 57, 0, 0, 57, 'Beginning', '2015-07-31', 550.00, 178.57),
	(885, 885, 0, 0, 0, 0, 'Beginning', '2015-07-31', 550.00, 300.00),
	(886, 886, 0, 0, 0, 0, 'Beginning', '2015-07-31', 550.00, 300.00),
	(887, 887, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2327.00, 1624.00),
	(888, 888, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1125.00, 875.00),
	(890, 890, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4509.00, 2818.75),
	(891, 891, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2857.14),
	(892, 892, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1160.71),
	(893, 893, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3928.57),
	(894, 894, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 356.25),
	(895, 895, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 356.25),
	(896, 896, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 312.50),
	(897, 897, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9383.04),
	(900, 900, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1480.00, 841.07),
	(901, 901, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1595.00, 1034.82),
	(904, 904, 1, 0, 1, 0, 'sold2015-77', '2015-12-14', 1859.00, 937.50),
	(905, 905, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(906, 906, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1859.00, 937.50),
	(907, 907, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1859.00, 937.50),
	(908, 908, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1859.00, 937.50),
	(909, 909, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(910, 910, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2767.86),
	(911, 911, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3392.86),
	(912, 912, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2026.79),
	(913, 913, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2026.79),
	(914, 914, 1, 0, 0, 1, 'Beginning', '2015-07-31', 22770.00, 12321.43),
	(916, 916, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2460.71),
	(917, 917, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12572.32),
	(918, 918, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9756.25),
	(919, 919, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3674.00, 1767.86),
	(920, 920, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3674.00, 1767.86),
	(921, 921, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1767.86),
	(922, 922, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3674.00, 1767.86),
	(923, 923, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3674.00, 1767.86),
	(924, 924, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 258.93),
	(925, 925, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 678.57),
	(926, 926, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 223.21),
	(927, 927, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1250.00),
	(929, 929, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5346.00, 2589.29),
	(931, 931, 1, 0, 1, 0, 'sold2015-74', '2015-12-12', 5346.00, 2589.29),
	(933, 933, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 366.07),
	(935, 935, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(936, 936, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(939, 939, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 258.93),
	(940, 940, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7857.14),
	(941, 941, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 16337.50),
	(946, 946, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2732.14),
	(948, 948, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1583.93),
	(949, 949, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4941.07),
	(950, 950, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4285.71),
	(951, 951, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 955.36),
	(952, 952, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6033.93),
	(954, 954, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 0.00),
	(955, 955, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1339.29),
	(956, 956, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1339.29),
	(957, 957, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1160.71),
	(958, 958, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1160.71),
	(959, 959, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1428.57),
	(960, 960, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1428.57),
	(966, 966, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1066.96),
	(967, 967, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1066.96),
	(968, 968, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1066.96),
	(969, 969, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1066.96),
	(970, 970, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1515.46),
	(971, 971, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1515.46),
	(972, 972, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1515.46),
	(973, 973, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1548.21),
	(976, 976, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1683.93),
	(979, 979, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(980, 980, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2200.00, 1089.29),
	(981, 981, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2200.00, 1089.29),
	(982, 982, 2, 0, 0, 2, 'Beginning', '2015-07-31', 2200.00, 1089.29),
	(983, 983, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2200.00, 1089.29),
	(984, 984, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(985, 985, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(986, 986, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(987, 987, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(988, 988, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(989, 989, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(990, 990, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(991, 991, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(992, 992, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(993, 993, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(994, 994, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(995, 995, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1089.29),
	(996, 996, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(997, 997, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(998, 998, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(999, 999, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1000, 1000, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1001, 1001, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1002, 1002, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1066.96),
	(1006, 1006, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4265.00, 2424.11),
	(1007, 1007, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1454.46),
	(1010, 1010, 0, 0, 0, 0, 'Beginning', '2015-07-31', 29777.00, 16918.75),
	(1011, 1011, 1, 0, 1, 0, 'Sales', '2015-07-31', 605.00, 343.75),
	(1012, 1012, 1, 0, 0, 1, 'Beginning', '2015-07-31', 17050.00, 0.00),
	(1013, 1013, 1, 0, 0, 1, 'Beginning', '2015-07-31', 10780.00, 5107.14),
	(1014, 1014, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9515.00, 5107.14),
	(1015, 1015, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9515.00, 5107.14),
	(1016, 1016, 1, 0, 0, 1, 'Beginning', '2015-07-31', 16830.00, 8995.54),
	(1017, 1017, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9515.00, 8995.54),
	(1018, 1018, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9515.00, 8995.54),
	(1019, 1019, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8281.25),
	(1020, 1020, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1428.57),
	(1021, 1021, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1887.50),
	(1022, 1022, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9731.25),
	(1023, 1023, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 32910.71),
	(1024, 1024, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 18821.43),
	(1025, 1025, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 448.21),
	(1026, 1026, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 683.04),
	(1029, 1029, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1030, 1030, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1031, 1031, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1032, 1032, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1033, 1033, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1034, 1034, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1035, 1035, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2907.14),
	(1036, 1036, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1819.64),
	(1037, 1037, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1681.25),
	(1038, 1038, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1681.25),
	(1039, 1039, 1, 0, 1, 0, 'sold2015-82', '2015-12-18', 2970.00, 1681.25),
	(1040, 1040, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1681.25),
	(1041, 1041, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1681.25),
	(1042, 1042, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1508.04),
	(1043, 1043, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5830.00, 3642.86),
	(1044, 1044, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1035.71),
	(1045, 1045, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1046, 1046, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1047, 1047, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1048, 1048, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1049, 1049, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1050, 1050, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1051, 1051, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1052, 1052, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 937.50),
	(1053, 1053, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1980.00, 1062.50),
	(1054, 1054, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1055, 1055, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1980.00, 1062.50),
	(1056, 1056, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1057, 1057, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1058, 1058, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1059, 1059, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2310.00, 1241.07),
	(1060, 1060, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1241.07),
	(1061, 1061, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1980.00, 1062.50),
	(1062, 1062, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1063, 1063, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2860.00, 1535.71),
	(1064, 1064, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1535.71),
	(1065, 1065, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1535.71),
	(1066, 1066, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1980.00, 1062.50),
	(1067, 1067, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1068, 1068, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1069, 1069, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1980.00, 1062.50),
	(1070, 1070, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1071, 1071, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2860.00, 1535.71),
	(1072, 1072, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1535.71),
	(1073, 1073, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1062.50),
	(1074, 1074, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1980.00, 1062.50),
	(1086, 1086, 1, 0, 1, 0, 'sold2015-53', '2015-10-26', 5525.00, 0.00),
	(1087, 1087, 1, 0, 0, 1, 'Beginning', '2015-07-31', 8165.00, 5300.00),
	(1088, 1088, 0, 0, 0, 0, 'Beginning', '2015-07-31', 105.00, 42.00),
	(1089, 1089, 0, 0, 0, 0, 'Beginning', '2015-07-31', 1010.00, 725.00),
	(1090, 1090, 3, 0, 3, 0, 'sold2015-66', '2015-11-19', 435.00, 0.00),
	(1091, 1091, 2, 0, 2, 0, 'sold2015-59', '2015-11-02', 435.00, 0.00),
	(1092, 1092, 1, 0, 1, 0, 'sold2015-80', '2015-12-14', 435.00, 0.00),
	(1093, 1093, 0, 0, 0, 0, 'Beginning', '2015-07-31', 385.00, 0.00),
	(1094, 1094, 5, 0, 2, 3, 'sold2015-46', '2015-10-19', 880.00, 450.00),
	(1095, 1095, 9, 0, 2, 7, 'Sales', '2015-07-31', 880.00, 450.00),
	(1096, 1096, 5, 0, 0, 5, 'Beginning', '2015-07-31', 880.00, 450.00),
	(1097, 1097, 1, 0, 1, 0, 'sold2015-79', '2015-12-14', 880.00, 450.00),
	(1098, 1098, 2, 0, 2, 0, 'sold2015-76', '2015-12-14', 880.00, 450.00),
	(1099, 1099, 2, 0, 1, 1, 'sold2015-78', '2015-12-14', 880.00, 450.00),
	(1100, 1100, 0, 0, 0, 0, 'Beginning', '2015-07-31', 510.00, 292.00),
	(1101, 1101, 0, 0, 0, 0, 'Beginning', '2015-07-31', 510.00, 292.00),
	(1102, 1102, 0, 0, 0, 0, 'Beginning', '2015-07-31', 510.00, 292.00),
	(1103, 1103, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4510.00, 0.00),
	(1104, 1104, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4510.00, 0.00),
	(1105, 1105, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 812.50),
	(1106, 1106, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 19785.71),
	(1107, 1107, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11071.43),
	(1108, 1108, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3982.00, 2644.64),
	(1109, 1109, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2644.64),
	(1110, 1110, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2714.29),
	(1111, 1111, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2714.29),
	(1112, 1112, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2714.29),
	(1113, 1113, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2139.29),
	(1114, 1114, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2544.64),
	(1115, 1115, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3142.86),
	(1116, 1116, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4785.71),
	(1118, 1118, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3642.86),
	(1119, 1119, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3428.57),
	(1120, 1120, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3428.57),
	(1121, 1121, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(1122, 1122, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(1123, 1123, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2310.00, 1440.18),
	(1124, 1124, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2020.00, 1440.18),
	(1125, 1125, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1440.18),
	(1126, 1126, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(1127, 1127, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(1128, 1128, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2640.00, 1714.29),
	(1129, 1129, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(1130, 1130, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1406.25),
	(1131, 1131, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2020.00, 1441.07),
	(1132, 1132, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1441.07),
	(1133, 1133, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2530.00, 1540.18),
	(1134, 1134, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1540.18),
	(1135, 1135, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1540.18),
	(1136, 1136, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1540.18),
	(1137, 1137, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2530.00, 1540.18),
	(1138, 1138, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1540.18),
	(1139, 1139, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1406.25),
	(1140, 1140, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1406.25),
	(1141, 1141, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2310.00, 1406.25),
	(1142, 1142, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1214.29),
	(1143, 1143, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2600.00, 1406.25),
	(1144, 1144, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2089.29),
	(1145, 1145, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1442.86),
	(1146, 1146, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1441.07),
	(1147, 1147, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 900.00),
	(1148, 1148, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1760.00, 1142.86),
	(1149, 1149, 1, 0, 0, 1, 'Beginning', '2015-07-31', 1870.00, 1214.28),
	(1150, 1150, 1, 0, 0, 1, 'Beginning', '2015-07-31', 2640.00, 1714.29),
	(1151, 1151, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1714.29),
	(1152, 1152, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1406.25),
	(1177, 1177, 1, 0, 0, 1, 'Beginning', '2015-07-31', 27000.00, 19285.71),
	(1178, 1178, 1, 0, 1, 0, 'sold2015-75', '2015-12-12', 10010.00, 0.00),
	(1179, 1179, 1, 0, 0, 1, 'Beginning', '2015-07-31', 19405.00, 0.00),
	(1180, 1180, 1, 0, 0, 1, 'Beginning', '2015-07-31', 20020.00, 0.00),
	(1181, 1181, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4125.00, 0.00),
	(1182, 1182, 1, 0, 1, 0, 'sold', '2015-09-10', 9735.00, 5531.25),
	(1183, 1183, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9735.00, 5531.25),
	(1184, 1184, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7687.50),
	(1185, 1185, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8250.00),
	(1186, 1186, 0, 0, 0, 0, 'Beginning', '2015-07-31', 11210.00, 6937.50),
	(1187, 1187, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6937.50),
	(1188, 1188, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 12656.25),
	(1189, 1189, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5468.75),
	(1190, 1190, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 8156.25),
	(1191, 1191, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5093.75),
	(1192, 1192, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5093.75),
	(1193, 1193, 0, 0, 0, 0, 'Beginning', '2015-07-31', 8965.00, 5093.75),
	(1194, 1194, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9000.00, 3000.00),
	(1195, 1195, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4687.50),
	(1196, 1196, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4687.50),
	(1197, 1197, 1, 0, 0, 1, 'Beginning', '2015-07-31', 6600.00, 3750.00),
	(1198, 1198, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3750.00),
	(1199, 1199, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3562.50),
	(1200, 1200, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 5625.00),
	(1201, 1201, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6562.50),
	(1202, 1202, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3281.25),
	(1203, 1203, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5775.00, 3281.25),
	(1204, 1204, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3000.00),
	(1205, 1205, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5280.00, 3000.00),
	(1206, 1206, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5280.00, 3000.00),
	(1207, 1207, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5280.00, 3000.00),
	(1208, 1208, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5280.00, 3000.00),
	(1209, 1209, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5280.00, 3000.00),
	(1210, 1210, 1, 0, 1, 0, 'sold2015-75', '2015-12-12', 3960.00, 0.00),
	(1211, 1211, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3960.00, 0.00),
	(1212, 1212, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7500.00),
	(1213, 1213, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2250.00),
	(1214, 1214, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3960.00, 2250.00),
	(1216, 1216, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4150.00, 0.00),
	(1217, 1217, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5555.00, 3213.00),
	(1218, 1218, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5555.00, 3213.00),
	(1219, 1219, 1, 0, 1, 0, 'sold2015-62', '2015-11-11', 3460.00, 2246.25),
	(1220, 1220, 2, 0, 2, 0, 'sold', '2015-10-06', 3700.00, 2396.25),
	(1221, 1221, 2, 0, 2, 0, 'sold', '2015-09-23', 2655.00, 0.00),
	(1222, 1222, 1, 0, 1, 0, 'sold2015-54', '2015-10-26', 3700.00, 2396.25),
	(1223, 1223, 1, 0, 1, 0, 'sold', '2015-09-14', 2885.00, 2396.25),
	(1224, 1224, 1, 0, 1, 0, 'Sales', '2015-07-31', 2655.00, 1721.25),
	(1225, 1225, 1, 0, 1, 0, 'sold2015-44', '2015-10-16', 2305.00, 1496.25),
	(1226, 1226, 1, 0, 1, 0, 'sold', '2015-09-21', 2885.00, 1871.25),
	(1227, 1227, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2655.00, 2295.00),
	(1228, 1228, 1, 0, 1, 0, 'sold2015-54', '2015-10-26', 2655.00, 2295.00),
	(1229, 1229, 0, 0, 0, 0, 'Beginning', '2015-07-31', 2655.00, 2295.00),
	(1230, 1230, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3465.00, 3150.00),
	(1231, 1231, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3700.00, 3150.00),
	(1232, 1232, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4830.00, 0.00),
	(1233, 1233, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4830.00, 0.00),
	(1234, 1234, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4830.00, 0.00),
	(1235, 1235, 1, 0, 1, 0, 'sold', '2015-09-05', 4150.00, 0.00),
	(1236, 1236, 1, 0, 1, 0, 'sold2015-81', '2015-12-14', 4750.00, 0.00),
	(1237, 1237, 1, 0, 1, 0, 'sold2015-64', '2015-11-14', 3280.00, 0.00),
	(1238, 1238, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3340.00, 2128.00),
	(1239, 1239, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3020.00, 0.00),
	(1240, 1240, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3280.00, 0.00),
	(1241, 1241, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5055.00, 0.00),
	(1242, 1242, 1, 0, 0, 1, 'Beginning', '2015-07-31', 39050.00, 0.00),
	(1243, 1243, 1, 0, 0, 1, 'Beginning', '2015-07-31', 18500.00, 0.00),
	(1248, 1248, 1, 0, 0, 1, 'Beginning', '2015-07-31', 5270.00, 3125.00),
	(1250, 1250, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4917.00, 2678.57),
	(1251, 1251, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2678.57),
	(1252, 1252, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1964.29),
	(1253, 1253, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1964.29),
	(1254, 1254, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1964.29),
	(1255, 1255, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3509.00, 1964.29),
	(1256, 1256, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2232.14),
	(1257, 1257, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2232.14),
	(1258, 1258, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2232.14),
	(1259, 1259, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2232.14),
	(1260, 1260, 1, 0, 0, 1, 'Beginning', '2015-07-31', 4950.00, 2946.43),
	(1261, 1261, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2946.43),
	(1262, 1262, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2946.43),
	(1263, 1263, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2946.43),
	(1264, 1264, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(1265, 1265, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(1266, 1266, 1, 0, 1, 0, 'sold2015-74', '2015-12-12', 1620.00, 1205.36),
	(1267, 1267, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2187.50),
	(1268, 1268, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2187.50),
	(1269, 1269, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1116.07),
	(1270, 1270, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1116.07),
	(1271, 1271, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1116.07),
	(1272, 1272, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(1273, 1273, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(1274, 1274, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(1275, 1275, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1205.36),
	(1289, 1289, 1, 0, 0, 1, 'Beginning', '2015-07-31', 6842.00, 3357.14),
	(1290, 1290, 1, 0, 0, 1, 'Beginning', '2015-07-31', 10164.00, 6865.51),
	(1291, 1291, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 9142.86),
	(1292, 1292, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 7212.05),
	(1293, 1293, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 3392.86),
	(1294, 1294, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 2107.14),
	(1295, 1295, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1392.86),
	(1296, 1296, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1214.29),
	(1297, 1297, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 1200.00),
	(1298, 1298, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 11285.72),
	(1299, 1299, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4339.29),
	(1300, 1300, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 4339.29),
	(1301, 1301, 1, 0, 0, 1, 'Beginning', '2015-07-31', 12345.00, 0.00),
	(1302, 1302, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9320.00, 0.00),
	(1303, 1303, 1, 0, 0, 1, 'Beginning', '2015-07-31', 13070.00, 0.00),
	(1304, 1304, 1, 0, 0, 1, 'Beginning', '2015-07-31', 9317.00, 0.00),
	(1305, 1305, 1, 0, 0, 1, 'Beginning', '2015-07-31', 8954.00, 5604.91),
	(1306, 1306, 0, 0, 0, 0, 'Beginning', '2015-07-31', 12584.00, 5604.91),
	(1316, 1316, 1, 0, 0, 1, 'Beginning', '2015-07-31', 7623.00, 5303.57),
	(1317, 1317, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 6291.67),
	(1318, 1318, 0, 0, 0, 0, 'Beginning', '2015-07-31', 10890.00, 6291.67),
	(1334, 1334, 2, 0, 0, 2, 'Beginning', '2015-07-31', 5855.00, 2883.93),
	(1335, 1335, 0, 0, 0, 0, 'Beginning', '2015-07-31', 5855.00, 2883.93),
	(1336, 1336, 0, 0, 0, 0, 'Beginning', '2015-07-31', 4195.00, 2428.57),
	(1339, 1339, 0, 0, 0, 0, 'Beginning', '2015-07-31', 3115.00, 0.00),
	(1340, 1340, 1, 0, 0, 1, 'Beginning', '2015-07-31', 6437.20, 0.00),
	(1345, 1345, 1, 0, 0, 1, 'Beginning', '2015-07-31', 3115.00, 0.00),
	(1351, 1351, 42, 0, 12, 30, 'sold', '2015-11-23', 540.00, 328.94),
	(1353, 1353, 0, 0, 0, 0, 'Beginning', '2015-07-31', 320.00, 191.07),
	(1354, 1354, 22, 0, 0, 22, 'Beginning', '2015-07-31', 583.00, 378.57),
	(1355, 1355, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 169.64),
	(1356, 1356, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 180.36),
	(1357, 1357, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 183.93),
	(1358, 1358, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 263.39),
	(1359, 1359, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 980.36),
	(1360, 1360, 14, 0, 1, 13, 'Sales', '2015-07-31', 468.00, 260.72),
	(1361, 1361, 2, 0, 0, 2, 'Beginning', '2015-07-31', 242.00, 139.29),
	(1362, 1362, 12, 0, 1, 11, 'Sales', '2015-07-31', 182.00, 111.61),
	(1364, 1364, 12, 5, 9, 8, 'sold2015-73', '2015-12-12', 805.00, 466.07),
	(1365, 1365, 0, 0, 0, 0, 'Beginning', '2015-07-31', 358.00, 205.36),
	(1366, 1366, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 317.41),
	(1367, 1367, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 289.29),
	(1368, 1368, 8, 0, 1, 7, 'sold', '2015-11-11', 809.00, 466.07),
	(1369, 1369, 14, 0, 0, 14, 'Beginning', '2015-07-31', 864.00, 498.86),
	(1370, 1370, 44, 0, 2, 42, 'Sales', '2015-07-31', 960.00, 554.46),
	(1371, 1371, 37, 0, 26, 11, 'sold', '2015-11-27', 655.00, 377.68),
	(1372, 1372, 9, 2, 4, 7, 'sold2015-48', '2015-10-17', 670.00, 432.00),
	(1373, 1373, 0, 0, 0, 0, 'Beginning', '2015-07-31', 0.00, 795.54),
	(1374, 1374, 4, 0, 0, 4, 'Beginning', '2015-07-31', 1039.00, 602.68),
	(1375, 1375, 10, 0, 6, 4, 'sold', '2015-12-16', 650.00, 337.50),
	(1376, 1376, 1, 0, 1, 0, 'sold', '2015-09-05', 655.00, 377.68),
	(1377, 1377, 0, 5, 2, 3, 'sold', '2015-10-15', 670.00, 432.00),
	(1378, 1378, 0, 0, 0, 0, 'IC', '2015-09-19', 0.00, 0.00),
	(1379, 1379, 0, 0, 0, 0, 'IC', '2015-09-19', 0.00, 0.00),
	(1380, 1380, 0, 1, 1, 0, 'sold2015-64', '2015-11-14', 2310.00, 1125.00),
	(1381, 1381, 0, 5, 2, 3, 'sold', '2015-12-11', 150.00, 80.00),
	(1382, 1382, 0, 1, 1, 0, 'sold', '2015-09-10', 52175.00, 36523.00),
	(1383, 1383, 0, 6, 0, 6, 'received 2015-10', '2015-10-01', 290.00, 181.58),
	(1384, 1384, 0, 1, 0, 1, 'received 2015-11', '2015-08-26', 550.00, 128.00),
	(1385, 1385, 0, 1, 1, 0, 'sold2015-44', '2015-10-16', 550.00, 128.00),
	(1386, 1386, 0, 1, 0, 1, 'received 2015-11', '2015-08-26', 550.00, 128.00),
	(1387, 1387, 0, 1, 0, 1, 'received 2015-12', '2015-10-03', 900.00, 653.25),
	(1388, 1388, 0, 1, 1, 0, 'sold', '2015-11-27', 125.00, 53.57),
	(1389, 1389, 0, 1, 0, 1, 'received 2015-12', '2015-10-03', 550.00, 187.71),
	(1390, 1390, 0, 1, 0, 1, 'received 2015-13', '2015-10-05', 175.00, 175.00),
	(1391, 1391, 0, 1, 0, 1, 'received 2015-13', '2015-10-05', 145.00, 145.00),
	(1392, 1392, 0, 1, 0, 1, 'received 2015-14', '2015-10-05', 160.00, 160.00),
	(1393, 1393, 0, 1, 0, 1, 'received 2015-14', '2015-10-05', 30.00, 30.00),
	(1394, 1394, 0, 1, 0, 1, 'received 2015-14', '2015-10-05', 27.00, 27.00),
	(1395, 1395, 1, 0, 0, 1, 'IC', '2015-10-09', 180.00, 0.00),
	(1396, 1396, 1, 0, 0, 1, 'IC', '2015-10-09', 100.00, 0.00),
	(1397, 1397, 0, 1, 1, 0, 'sold', '2015-11-27', 250.00, 0.00),
	(1398, 1398, 0, 0, 0, 0, 'IC', '2015-10-17', 0.00, 0.00),
	(1399, 1399, 0, 1, 1, 0, 'sold2015-76', '2015-12-14', 1080.00, 625.00),
	(1400, 1400, 0, 2, 2, 0, 'sold2015-49', '2015-10-21', 1390.00, 800.00),
	(1401, 1401, 0, 2, 0, 2, 'received 2015-17', '2015-10-16', 5555.00, 2500.00),
	(1402, 1402, 0, 1, 0, 1, 'received 2015-17', '2015-10-16', 5555.00, 2500.00),
	(1403, 1403, 0, 1, 1, 0, 'sold2015-53', '2015-10-26', 5555.00, 2500.00),
	(1404, 1404, 0, 1, 0, 1, 'received 2015-17', '2015-10-16', 5555.00, 2500.00),
	(1405, 1405, 0, 1, 0, 1, 'received 2015-17', '2015-10-16', 5555.00, 2500.00),
	(1406, 1406, 0, 1, 1, 0, 'sold', '2015-10-26', 600.00, 388.57),
	(1407, 1407, 0, 0, 0, 0, 'IC', '2015-10-19', 0.00, 0.00),
	(1408, 1408, 0, 0, 0, 0, 'IC', '2015-10-19', 0.00, 0.00),
	(1409, 1409, 0, 0, 0, 0, 'IC', '2015-10-19', 0.00, 0.00),
	(1410, 1410, 0, 0, 0, 0, 'IC', '2015-10-19', 0.00, 0.00),
	(1411, 1411, 0, 0, 0, 0, 'IC', '2015-10-19', 0.00, 0.00),
	(1412, 1412, 0, 0, 0, 0, 'IC', '2015-10-20', 0.00, 0.00),
	(1413, 1413, 0, 0, 0, 0, 'IC', '2015-10-20', 0.00, 0.00),
	(1414, 1414, 0, 2, 1, 1, 'Invoice 27', '2015-11-07', 115000.00, 115000.00),
	(1415, 1415, 0, 1, 1, 0, 'pullout 2015-1', '2015-11-18', 650000.00, 650000.00),
	(1416, 1416, 0, 1, 1, 0, 'Invoice 29', '2015-11-11', 199000.00, 199000.00),
	(1417, 1417, 0, 1, 0, 1, 'received 2015-20', '2015-10-16', 75000.00, 57379.68),
	(1418, 1418, 0, 1, 1, 0, 'sold', '2015-11-12', 2750.00, 1339.28),
	(1419, 1419, 0, 1, 0, 1, 'received 2015-21', '2015-11-11', 1870.00, 1000.00),
	(1420, 1420, 0, 1, 1, 0, 'sold', '2015-11-11', 110.00, 53.57),
	(1421, 1421, 0, 1, 0, 1, 'received 2015-21', '2015-11-11', 620.00, 262.50),
	(1422, 1422, 0, 1, 0, 1, 'received 2015-22', '2015-11-18', 199000.00, 0.00),
	(1423, 1423, 0, 1, 0, 1, 'received 2015-22', '2015-11-18', 199000.00, 0.00),
	(1424, 1424, 0, 1, 1, 0, 'Invoice 35', '2015-11-28', 169000.00, 0.00),
	(1425, 1425, 0, 1, 0, 1, 'received 2015-22', '2015-11-18', 169000.00, 0.00),
	(1426, 1426, 0, 1, 0, 1, 'received 2015-22', '2015-11-18', 169000.00, 0.00),
	(1427, 1427, 0, 1, 0, 1, 'received 2015-22', '2015-11-18', 199000.00, 0.00),
	(1428, 1428, 0, 1, 0, 1, 'received 2015-22', '2015-11-18', 399000.00, 0.00),
	(1429, 1429, 0, 0, 0, 0, 'IC', '2015-11-19', 0.00, 0.00),
	(1430, 1430, 0, 1, 1, 0, 'sold2015-67', '2015-11-19', 75000.00, 57379.68),
	(1431, 1431, 0, 5, 0, 5, 'received 2015-24', '2015-11-17', 805.00, 466.07),
	(1432, 1432, 0, 5, 0, 5, 'received 2015-24', '2015-11-17', 670.00, 432.00),
	(1433, 1433, 0, 1, 1, 0, 'sold', '2015-12-17', 2420.00, 1382.50),
	(1434, 1434, 0, 2, 1, 1, 'sold2015-71', '2015-11-28', 550.00, 128.53),
	(1435, 1435, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 6920.00, 3931.25),
	(1436, 1436, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 6920.00, 3931.25),
	(1437, 1437, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 6590.00, 2868.75),
	(1438, 1438, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 5380.00, 3056.25),
	(1439, 1439, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 5555.00, 2868.75),
	(1440, 1440, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 4730.00, 2742.19),
	(1441, 1441, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 4730.00, 2742.19),
	(1442, 1442, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 4040.00, 2340.40),
	(1443, 1443, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 4505.00, 2742.18),
	(1444, 1444, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 4150.00, 2142.86),
	(1445, 1445, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 3675.00, 1900.00),
	(1446, 1446, 0, 12, 2, 10, 'sold2015-70', '2015-12-01', 655.00, 353.57),
	(1447, 1447, 0, 6, 0, 6, 'received 2015-25', '2015-11-23', 670.00, 371.43),
	(1448, 1448, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 9988.00, 5785.71),
	(1449, 1449, 0, 2, 0, 2, 'received 2015-25', '2015-11-23', 1320.00, 763.39),
	(1450, 1450, 0, 2, 1, 1, 'sold', '2015-12-09', 2090.00, 830.35),
	(1451, 1451, 0, 1, 0, 1, 'received 2015-25', '2015-11-23', 2310.00, 1125.00),
	(1452, 1452, 0, 1, 0, 1, 'received 2015-26', '2015-11-23', 6240.00, 2800.00),
	(1453, 1453, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 11330.00, 6087.63),
	(1454, 1454, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 11330.00, 6087.63),
	(1455, 1455, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 3410.00, 1805.00),
	(1456, 1456, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 3410.00, 1805.00),
	(1457, 1457, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 3410.00, 1805.00),
	(1458, 1458, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 3410.00, 1805.00),
	(1459, 1459, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 3410.00, 1805.00),
	(1460, 1460, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1461, 1461, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1462, 1462, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1463, 1463, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1464, 1464, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1465, 1465, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1466, 1466, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1467, 1467, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1468, 1468, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1469, 1469, 0, 2, 0, 2, 'received 2015-27', '2015-11-23', 1760.00, 917.77),
	(1470, 1470, 0, 1, 0, 1, 'received 2015-27', '2015-11-23', 2860.00, 1499.64),
	(1471, 1471, 0, 1, 0, 1, 'received 2015-28', '2015-11-23', 540000.00, 540000.00),
	(1472, 1472, 0, 2, 0, 2, 'received 2015-29', '2015-12-10', 925.00, 501.29),
	(1473, 1473, 0, 1, 0, 1, 'received 2015-29', '2015-12-10', 5705.00, 3529.46),
	(1474, 1474, 0, 1, 0, 1, 'received 2015-29', '2015-12-10', 5705.00, 3239.29),
	(1475, 1475, 0, 1, 0, 1, 'received 2015-29', '2015-12-10', 5705.00, 3239.29),
	(1476, 1476, 0, 4, 0, 4, 'received 2015-29', '2015-12-10', 965.00, 466.96),
	(1477, 1477, 0, 3, 0, 3, 'received 2015-29', '2015-12-10', 1390.00, 803.57),
	(1478, 1478, 0, 1, 1, 0, 'sold2015-75', '2015-12-12', 10780.00, 0.00),
	(1479, 1479, 0, 1, 0, 1, 'received 2015-29', '2015-12-10', 2655.00, 1721.25),
	(1480, 1480, 0, 1, 0, 1, 'received 2015-29', '2015-12-10', 2310.00, 0.00),
	(1481, 1481, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 7000.00, 4462.50),
	(1482, 1482, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 14720.00, 8500.00),
	(1483, 1483, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 1840.00, 1192.63),
	(1484, 1484, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 8045.00, 4660.72),
	(1485, 1485, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1486, 1486, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1487, 1487, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1488, 1488, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1489, 1489, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1490, 1490, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 144.96),
	(1491, 1491, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1492, 1492, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 144.96),
	(1493, 1493, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1494, 1494, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 130.22),
	(1495, 1495, 0, 1, 0, 1, 'received 2015-30', '2015-12-08', 550.00, 144.96);
/*!40000 ALTER TABLE `tblinventory` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitem
DROP TABLE IF EXISTS `tblitem`;
CREATE TABLE IF NOT EXISTS `tblitem` (
  `idItem` int(15) NOT NULL AUTO_INCREMENT,
  `idSupplier` int(10) DEFAULT NULL,
  `idBrand` int(5) DEFAULT NULL,
  `itemName` varchar(250) DEFAULT NULL,
  `detail` text,
  `idCategory` int(2) DEFAULT NULL,
  `idUnit` int(3) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `barcode` varchar(10) DEFAULT NULL,
  `cost` double(12,2) DEFAULT NULL,
  `sellingPrice` double(12,2) DEFAULT NULL,
  `begBalance` int(5) NOT NULL,
  `dateInput` date DEFAULT NULL,
  `percent` int(3) DEFAULT NULL,
  `dealerPrice` double(15,2) DEFAULT NULL,
  `dateUpdated` date DEFAULT NULL,
  `itemStatus` varchar(20) DEFAULT NULL,
  `idLocation` int(3) DEFAULT NULL,
  `partNum` varchar(20) DEFAULT NULL,
  `bikeModel` text,
  `vin` varchar(15) DEFAULT NULL,
  `idSkRm` int(5) DEFAULT NULL,
  PRIMARY KEY (`idItem`)
) ENGINE=InnoDB AUTO_INCREMENT=1496 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitem: ~1,121 rows (approximately)
/*!40000 ALTER TABLE `tblitem` DISABLE KEYS */;
INSERT INTO `tblitem` (`idItem`, `idSupplier`, `idBrand`, `itemName`, `detail`, `idCategory`, `idUnit`, `code`, `barcode`, `cost`, `sellingPrice`, `begBalance`, `dateInput`, `percent`, `dealerPrice`, `dateUpdated`, `itemStatus`, `idLocation`, `partNum`, `bikeModel`, `vin`, `idSkRm`) VALUES
	(2, 0, 22, 'Ducati Hypermotard 821 Red 14', 'Ducati Hypermotard 821 Red 14', 3, 3, 2, '', 0.00, 759000.00, 1, '2015-07-31', 0, 759000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(3, 0, 22, 'Ducati Scrambler Icon Yellow 15', 'Ducati Scrambler Icon Yellow 15', 3, 3, 3, '', 0.00, 550000.00, 0, '2015-07-31', 0, 550000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(4, 0, 22, 'Diavel Dark Steal Black 2015', 'Diavel Dark Steal Black 2015', 3, 3, 4, '', 447857.14, 1199000.00, 0, '2015-07-31', 0, 1199000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(5, 0, 22, 'Hyperstrada Red 14 - Brandnew ', 'Hyperstrada Red 14 - Brandnew ', 3, 3, 5, '', 0.00, 839000.00, 0, '2015-07-31', 0, 839000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(6, 0, 22, 'Hyperstrada Red 15 - Brandnew ', 'Hyperstrada Red 15 - Brandnew ', 3, 3, 6, '', 0.00, 839000.00, 1, '2015-07-31', 0, 839000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(7, 0, 22, 'Hyperstrada Red 14 - slightly use w/ termignoni pipe ', 'Hyperstrada Red 14 - slightly use w/ termignoni pipe ', 3, 3, 7, '', 0.00, 839000.00, 0, '2015-07-31', 0, 839000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(8, 0, 22, ' Monster 795', ' Monster 795', 3, 3, 8, '', 0.00, 570000.00, 0, '2015-07-31', 0, 570000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(11, 0, 3, 'Preowned- Ktm Freeride 350 Brand New White / Orange 2014', 'Preowned- Ktm Freeride 350 Brand New White / Orange 2014', 3, 3, 11, '', 0.00, 450000.00, 0, '2015-07-31', 0, 450000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(12, 0, 3, 'Ktm Freeride 350 Brand New White / Orange 2014', 'Ktm Freeride 350 Brand New White / Orange 2014', 3, 3, 12, '', 0.00, 599000.00, 0, '2015-07-31', 0, 599000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(13, 0, 3, 'Ktm RC 200 non-abs Black 2015', 'Ktm RC 200 non-abs Black 2015', 3, 3, 13, '', 0.00, 199000.00, 5, '2015-07-31', 12, 199000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'NDC-TMP', 0),
	(14, 0, 3, 'Ktm RC 390 abs White 2015', 'Ktm RC 390 abs White 2015', 3, 3, 14, '', 0.00, 399000.00, 2, '2015-07-31', 0, 399000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(15, 0, 3, 'Duke 200 2012 - Modified ', 'Duke 200 2012 - Modified ', 3, 3, 15, '', 178750.00, 178750.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(16, 0, 3, 'Duke 200 2012 - Preowned bike ', 'Duke 200 2012 - Preowned bike ', 3, 3, 16, '', 178750.00, 178750.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(17, 0, 3, 'Ktm Duke 200 Non-Abs 2014', 'Ktm Duke 200 Non-Abs 2014', 3, 3, 17, '', 0.00, 169000.00, 4, '2015-07-31', 0, 159000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(18, 0, 3, 'Ktm Duke 200 Non-Abs 2014 - DE CONTENT ', 'Ktm Duke 200 Non-Abs 2014 - DE CONTENT ', 3, 3, 18, '', 0.00, 0.00, 1, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(19, 0, 3, 'Ktm Duke 200 Non-Abs 2013', 'Ktm Duke 200 Non-Abs 2013', 3, 3, 19, '', 0.00, 159000.00, 0, '2015-07-31', 0, 159000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(20, 0, 3, 'Ktm Duke 200 Abs 2013', 'Ktm Duke 200 Abs 2013', 3, 3, 20, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(21, 0, 3, 'Ktm Duke 390 Abs - 2014 - DEMO BIKE ', 'Ktm Duke 390 Abs - 2014 - DEMO BIKE ', 3, 3, 21, '', 0.00, 0.00, 1, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(22, 0, 3, 'Ktm Duke 390  Abs - 2014', 'Ktm Duke 390  Abs - 2014', 3, 3, 22, '', 0.00, 299000.00, 11, '2015-07-31', 0, 299000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(23, 0, 40, 'YAMAHA FZ-09 ORANGE 2014', 'YAMAHA FZ-09 ORANGE 2014', 3, 3, 23, '', 0.00, 620000.00, 1, '2015-07-31', 0, 620000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(24, 0, 40, 'ITALJET FORMULA 125 TRICOLORE  2015', 'ITALJET FORMULA 125 TRICOLORE  2015', 3, 3, 24, '', 0.00, 105000.00, 1, '2015-07-31', 0, 105000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(25, 0, 40, 'HONDA CBR100 BLACK RR - 2014', 'HONDA CBR100 BLACK RR - 2014', 3, 3, 25, '', 0.00, 870000.00, 0, '2015-07-31', 0, 870000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(26, 0, 4, 'VESPA PRIMAVERA 150 BLACK 2015', 'VESPA PRIMAVERA 150 BLACK 2015', 3, 3, 26, '', 0.00, 229000.00, 1, '2015-07-31', 0, 229000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(27, 0, 4, 'VESPA LXV 150 3Vie', 'VESPA LXV 150 3Vie', 3, 3, 27, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(28, 0, 4, 'VESPA PX 150', 'VESPA PX 150', 3, 3, 28, '', 0.00, 249000.00, 0, '2015-07-31', 0, 249000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(29, 0, 4, 'VESPA LX150 2Vie', 'VESPA LX150 2Vie', 3, 3, 29, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(30, 0, 4, 'PIAGGIO TYPHOON 125', 'PIAGGIO TYPHOON 125', 3, 3, 30, '', 79553.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(31, 0, 4, 'PIAGGIO LML STAR 200 - DEMO BIKE ', 'PIAGGIO LML STAR 200 - DEMO BIKE ', 3, 3, 31, '', 79553.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(33, 0, 6, 'HUSQVARNA TERRA 650 ', 'HUSQVARNA TERRA 650 ', 3, 3, 33, '', 285714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(36, 0, 7, 'REGULATOR 999 B/03 - 54040191A', 'REGULATOR 999 B/03 - 54040191A', 1, 9, 36, '', 0.00, 10765.00, 2, '2015-07-31', 0, 10765.00, '2015-07-31', 'BRANDNEW', 3, '54040191A', '', 'SHOWROOM', 0),
	(37, 0, 7, 'OHLIN FORK OIL SEAL ', 'OHLIN FORK OIL SEAL ', 1, 9, 37, '', 0.00, 6900.00, 0, '2015-07-31', 0, 6900.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(38, 0, 7, 'REAR FLASHER LIGHT RHS - 53010164A', 'REAR FLASHER LIGHT RHS - 53010164A', 1, 1, 38, '', 0.00, 2545.00, 0, '2015-07-31', 0, 2545.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(39, 0, 7, '96979707B-1098 COVER CARBON FUEL PLUG', '96979707B-1098 COVER CARBON FUEL PLUG', 1, 1, 39, '', 8775.00, 15876.00, 1, '2015-07-31', 0, 15876.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(40, 0, 7, '96644810B - 2010 FOOTPEGS SBK KIT', '96644810B - 2010 FOOTPEGS SBK KIT', 1, 1, 40, '', 43140.18, 72474.00, 1, '2015-07-31', 0, 72474.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(41, 0, 9, 'BAGS DUCATI REAR-1098- 967591AAA', 'BAGS DUCATI REAR-1098- 967591AAA', 2, 1, 41, '', 7180.36, 12372.00, 1, '2015-07-31', 0, 12372.00, '2015-07-31', 'BRANDNEW', 3, '967591AAA', '', 'SHOWROOM', 0),
	(42, 0, 7, '969A05107B COVER SBK CARBON-IGNITION SWITCH', '969A05107B COVER SBK CARBON-IGNITION SWITCH', 1, 1, 42, '', 6881.25, 11010.00, 1, '2015-07-31', 0, 11010.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(43, 0, 7, '969A04208B COVER SBK CARBON-SPROCKET', '969A04208B COVER SBK CARBON-SPROCKET', 1, 1, 43, '', 6604.46, 11520.00, 1, '2015-07-31', 0, 11520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(44, 0, 7, '96628507BA-1098/848 SIGNAL LIGHT TURN INDICATOR', '96628507BA-1098/848 SIGNAL LIGHT TURN INDICATOR', 1, 1, 44, '', 6369.64, 11520.00, 1, '2015-07-31', 0, 11520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(45, 0, 7, '969A08009B CARBON 1098 CLUTCH COVER', '969A08009B CARBON 1098 CLUTCH COVER', 1, 1, 45, '', 6720.54, 10158.00, 1, '2015-07-31', 0, 10158.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(47, 0, 7, 'AIR FILTER 1098 - 42610201A', 'AIR FILTER 1098 - 42610201A', 1, 1, 47, '', 3701.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(48, 0, 7, 'AIR FILTER CARTRIDGE - FILTER 42610191A', 'AIR FILTER CARTRIDGE - FILTER 42610191A', 1, 1, 48, '', 654.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(49, 0, 7, 'AIR FILTER HYM1100S - 42610251A', 'AIR FILTER HYM1100S - 42610251A', 1, 1, 49, '', 990.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(50, 0, 7, 'AIR FILTER L.H. - 748, 996B - 42620021A', 'AIR FILTER L.H. - 748, 996B - 42620021A', 1, 1, 50, '', 614.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(51, 0, 7, 'AIR FILTER MS4/03 - 42610111A #017341-017287', 'AIR FILTER MS4/03 - 42610111A #017341-017287', 1, 1, 51, '', 843.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(52, 0, 7, 'AIR FILTER R.H. - 748, 996B - 42620031A', 'AIR FILTER R.H. - 748, 996B - 42620031A', 1, 1, 52, '', 614.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(53, 0, 9, 'BAGS DUCATI TOPCASE KIT - 96780121A', 'BAGS DUCATI TOPCASE KIT - 96780121A', 2, 1, 53, '', 28674.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(54, 0, 9, 'BAGS DUCATI-MONSTER-SEAT BAG - 96766709B', 'BAGS DUCATI-MONSTER-SEAT BAG - 96766709B', 2, 1, 54, '', 11889.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(55, 0, 7, 'BEARING 6003 TN9 C3 - 70250081A', 'BEARING 6003 TN9 C3 - 70250081A', 1, 1, 55, '', 337.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(56, 0, 7, 'BEARING 748,ST4 BALL BEARING 70250191A', 'BEARING 748,ST4 BALL BEARING 70250191A', 1, 1, 56, '', 975.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(58, 0, 7, 'BELT 1098S-07 - 73740251A', 'BELT 1098S-07 - 73740251A', 1, 1, 58, '', 2406.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(60, 0, 7, 'BELT 750M.SS-TOOTHED - 73710051A', 'BELT 750M.SS-TOOTHED - 73710051A', 1, 1, 60, '', 1950.90, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(61, 0, 7, 'BELT M750,SS-TOOTHED - 066029090', 'BELT M750,SS-TOOTHED - 066029090', 1, 1, 61, '', 944.65, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(63, 0, 7, 'BIKE STAND - CENTRAL STAND - 97080011A', 'BIKE STAND - CENTRAL STAND - 97080011A', 1, 1, 63, '', 8100.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(64, 0, 7, 'BOLT - 77915111B', 'BOLT - 77915111B', 1, 1, 64, '', 192.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(65, 0, 7, 'BRACKET RH FOOTREST - 82411631A', 'BRACKET RH FOOTREST - 82411631A', 1, 1, 65, '', 7488.39, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(66, 0, 7, 'BRAKE PAD 1098S/07 - FRONT - 61340791A', 'BRAKE PAD 1098S/07 - FRONT - 61340791A', 1, 1, 66, '', 5903.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(67, 0, 7, 'BRAKE PAD 696MR09-REAR - 61340871A -M696', 'BRAKE PAD 696MR09-REAR - 61340871A -M696', 1, 1, 67, '', 2980.36, 5562.00, 1, '2015-07-31', 0, 5562.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(69, 0, 7, 'BRAKE PAD -996B-ST4 - 61340211B', 'BRAKE PAD -996B-ST4 - 61340211B', 1, 1, 69, '', 4611.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(70, 0, 7, 'BRAKE PAD DIAVEL FRONT - 61340941A', 'BRAKE PAD DIAVEL FRONT - 61340941A', 1, 1, 70, '', 4468.36, 8930.00, 1, '2015-07-31', 0, 8930.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(71, 0, 7, 'BRAKE PAD FRONT SET - 61340611A', 'BRAKE PAD FRONT SET - 61340611A', 1, 1, 71, '', 2627.32, 5225.00, 0, '2015-07-31', 0, 5225.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(72, 0, 7, 'BRAKE PAD PAIR-748B,900M FRNT - 61340201A', 'BRAKE PAD PAIR-748B,900M FRNT - 61340201A', 1, 1, 72, '', 2668.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(73, 0, 7, 'BRAKE PAD -S2R-PAIR - 61340721A', 'BRAKE PAD -S2R-PAIR - 61340721A', 1, 1, 73, '', 1853.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(74, 0, 7, 'BRAKE PAD SF/10-PAIR - 61340901A', 'BRAKE PAD SF/10-PAIR - 61340901A', 1, 1, 74, '', 4501.98, 9325.00, 1, '2015-07-31', 0, 9325.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(75, 0, 7, 'BRAKE PEDAL LEVER - 45720491A', 'BRAKE PEDAL LEVER - 45720491A', 1, 1, 75, '', 3921.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(77, 0, 7, 'BRAKEPAD 748/996B PAIR - 61340081A', 'BRAKEPAD 748/996B PAIR - 61340081A', 1, 1, 77, '', 1373.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(78, 0, 7, 'BRAKEPAD 900MHE-REAR BRAKE - 61340381A -MTS', 'BRAKEPAD 900MHE-REAR BRAKE - 61340381A -MTS', 1, 1, 78, '', 1475.89, 3055.00, 2, '2015-07-31', 0, 3055.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(79, 0, 7, 'BRAKEPAD PADS PAIR - 61340931A', 'BRAKEPAD PADS PAIR - 61340931A', 1, 1, 79, '', 3837.22, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(80, 0, 7, 'BRAKEPAD SET REAR S4R - 61340541A', 'BRAKEPAD SET REAR S4R - 61340541A', 1, 1, 80, '', 1219.82, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(81, 0, 7, 'BRAKEPAD ST4/900SS - REAR SET - 61340211A', 'BRAKEPAD ST4/900SS - REAR SET - 61340211A', 1, 1, 81, '', 1102.82, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(82, 0, 7, 'CIRCLIP - RING SAFETY - 88450031A', 'CIRCLIP - RING SAFETY - 88450031A', 1, 1, 82, '', 16.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(83, 0, 7, 'CLAMP 10-7 74141711A ', 'CLAMP 10-7 74141711A ', 1, 1, 83, '', 39.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(84, 0, 7, 'CLAMP 74140581A', 'CLAMP 74140581A', 1, 1, 84, '', 180.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(85, 0, 7, 'CLUTCH CONTROL PIPE METAL PLAI - 63210541A', 'CLUTCH CONTROL PIPE METAL PLAI - 63210541A', 1, 1, 85, '', 2175.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(86, 0, 7, 'CLUTCH DISCS SET - 19020042A', 'CLUTCH DISCS SET - 19020042A', 1, 1, 86, '', 6342.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(87, 0, 7, 'CLUTCH KIT CLUTCH PLATES S2R/05 - 19020161A', 'CLUTCH KIT CLUTCH PLATES S2R/05 - 19020161A', 1, 1, 87, '', 10293.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(88, 0, 7, 'CLUTCH SPRING 748 - 79912531A', 'CLUTCH SPRING 748 - 79912531A', 1, 1, 88, '', 132.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(89, 0, 7, 'COVER - STD.SIL - CARBON - 96964703B-999/749', 'COVER - STD.SIL - CARBON - 96964703B-999/749', 1, 1, 89, '', 11543.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(90, 0, 7, 'COVER CARB RADIATOR COVER KIT HYS - 96989921A', 'COVER CARB RADIATOR COVER KIT HYS - 96989921A', 1, 1, 90, '', 12303.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(91, 0, 7, 'COVER CARBON HEADLIGHT UP 969A04709B', 'COVER CARBON HEADLIGHT UP 969A04709B', 1, 1, 91, '', 8002.68, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(92, 0, 7, 'COVER CARBON HEAT GUARD - 969A04609B', 'COVER CARBON HEAT GUARD - 969A04609B', 1, 1, 92, '', 3716.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(93, 0, 7, 'COVER CARBON TANK SIDE - 969A03808B', 'COVER CARBON TANK SIDE - 969A03808B', 1, 1, 93, '', 30364.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(94, 0, 7, 'COVER FOOTPEG - 24713131B', 'COVER FOOTPEG - 24713131B', 1, 1, 94, '', 433.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(95, 0, 7, 'COVER GAS CAP - MTS1200 - 96783410C', 'COVER GAS CAP - MTS1200 - 96783410C', 1, 1, 95, '', 13283.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(96, 0, 7, 'COVER MONSTER CARBON EXHAUST VALVE - 96995309B', 'COVER MONSTER CARBON EXHAUST VALVE - 96995309B', 1, 1, 96, '', 5280.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(97, 0, 7, 'COVER MONSTER CARBON TANK LOW - 696A04909B', 'COVER MONSTER CARBON TANK LOW - 696A04909B', 1, 1, 97, '', 6881.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(98, 0, 7, 'COVER MONSTER CARBON TANK UP - 969A05009B', 'COVER MONSTER CARBON TANK UP - 969A05009B', 1, 1, 98, '', 13283.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(99, 0, 7, 'COVER MR696 CARBON SPROCKET - 969A03709B', 'COVER MR696 CARBON SPROCKET - 969A03709B', 1, 1, 99, '', 5602.68, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(100, 0, 7, 'COVER PEDAL RUBBER - 76410112A', 'COVER PEDAL RUBBER - 76410112A', 1, 1, 100, '', 218.39, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(101, 0, 7, 'COVER SF-HEAT GUARD - 96313310B', 'COVER SF-HEAT GUARD - 96313310B', 1, 1, 101, '', 13668.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(102, 0, 7, 'CRASHBAR MTS1200 - 96674210B', 'CRASHBAR MTS1200 - 96674210B', 1, 1, 102, '', 13815.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(103, 0, 7, 'BREMBO REAR PAD SET PAD - 61340381A', 'BREMBO REAR PAD SET PAD - 61340381A', 1, 1, 103, '', 0.00, 3055.00, 1, '2015-07-31', 0, 3055.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(104, 0, 7, 'DUCATI TUBE COMP. INNER LEFT KAYABA - 349210A', 'DUCATI TUBE COMP. INNER LEFT KAYABA - 349210A', 1, 1, 104, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(105, 0, 7, 'FAIRING KIT CARBON HEADLIGHT-RACING - 96902912A', 'FAIRING KIT CARBON HEADLIGHT-RACING - 96902912A', 1, 1, 105, '', 10443.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(106, 0, 7, 'FAIRING VR-MONSTER V-ROSSI46 69926151VR', 'FAIRING VR-MONSTER V-ROSSI46 69926151VR', 1, 1, 106, '', 43467.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(107, 0, 7, 'LEFT BRACKET M795 - 82919711A', 'LEFT BRACKET M795 - 82919711A', 1, 1, 107, '', 0.00, 504.00, 0, '2015-07-31', 0, 504.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(108, 0, 7, 'LEVER 1098S/07 BRAKE PEDAL - 45720421A', 'LEVER 1098S/07 BRAKE PEDAL - 45720421A', 1, 1, 108, '', 4594.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(109, 0, 7, 'LEVER 1098S/08 -GEARCHANGE PEDAL - 45610541A', 'LEVER 1098S/08 -GEARCHANGE PEDAL - 45610541A', 1, 1, 109, '', 3464.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(110, 0, 7, 'LEVER 1198S- BLACK 45610541AB', 'LEVER 1198S- BLACK 45610541AB', 1, 1, 110, '', 3602.68, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(111, 0, 7, 'LEVER 600M-750-02 BRAKE LEVER - 62610021A', 'LEVER 600M-750-02 BRAKE LEVER - 62610021A', 1, 1, 111, '', 1169.64, 3726.00, 1, '2015-07-31', 0, 3726.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(112, 0, 7, 'LEVER 749-999 BRAKE LEVER - 62640271A', 'LEVER 749-999 BRAKE LEVER - 62640271A', 1, 1, 112, '', 5250.89, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(113, 0, 7, 'LEVER 750-900 - GEARCHANGE - 45620071A', 'LEVER 750-900 - GEARCHANGE - 45620071A', 1, 1, 113, '', 3414.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(114, 0, 7, 'LEVER 750-900 SS - CLUTCH - 63140091A', 'LEVER 750-900 SS - CLUTCH - 63140091A', 1, 1, 114, '', 4275.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(115, 0, 7, 'LEVER BRAKE - HYM - 62640581A', 'LEVER BRAKE - HYM - 62640581A', 1, 1, 115, '', 5514.29, 8490.00, 1, '2015-07-31', 0, 8490.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(116, 0, 7, 'LEVER BRAKE DUCATI S2R1000/07 - 62610061A', 'LEVER BRAKE DUCATI S2R1000/07 - 62610061A', 1, 1, 116, '', 3132.23, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(117, 0, 7, 'LEVER BRAKE FRONT 696MR - 62640701A', 'LEVER BRAKE FRONT 696MR - 62640701A', 1, 1, 117, '', 4320.62, 10059.00, 1, '2015-07-31', 0, 10059.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(118, 0, 7, 'LEVER CLUTCH - HYM - 62640551A', 'LEVER CLUTCH - HYM - 62640551A', 1, 1, 118, '', 5514.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(119, 0, 7, 'LEVER CLUTCH 1098S/07 - 63140341A', 'LEVER CLUTCH 1098S/07 - 63140341A', 1, 1, 119, '', 5514.29, 7719.00, 1, '2015-07-31', 0, 7719.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(120, 0, 7, 'LEVER CLUTCH-M.CYLINDER 696MR - 62640711A', 'LEVER CLUTCH-M.CYLINDER 696MR - 62640711A', 1, 1, 120, '', 4320.62, 10059.00, 1, '2015-07-31', 0, 10059.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(121, 0, 7, 'LEVER FRONT 748-996B BRAKE LEVER - 62640071B', 'LEVER FRONT 748-996B BRAKE LEVER - 62640071B', 1, 1, 121, '', 3400.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(122, 0, 7, 'LEVER FRONT BRAKE 1098S/08 - 63140331A', 'LEVER FRONT BRAKE 1098S/08 - 63140331A', 1, 1, 122, '', 5514.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(123, 0, 7, 'LEVER GEARCHANGE PEDAL 1098SF/10 - 45612031A', 'LEVER GEARCHANGE PEDAL 1098SF/10 - 45612031A', 1, 1, 123, '', 3744.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(124, 0, 7, 'LEVER HYM/10 GEARBOX - 45620581AB', 'LEVER HYM/10 GEARBOX - 45620581AB', 1, 1, 124, '', 3381.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(125, 0, 7, 'LEVER HYM796 - GEARBOX - 45620352AB', 'LEVER HYM796 - GEARBOX - 45620352AB', 1, 1, 125, '', 4591.97, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(126, 0, 7, 'LEVER M62003 - CLUTCH - 62640071C', 'LEVER M62003 - CLUTCH - 62640071C', 1, 1, 126, '', 2139.29, 3992.00, 1, '2015-07-31', 0, 3992.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(127, 0, 7, 'LEVER MTS1000-CLUTCH - 62640341A', 'LEVER MTS1000-CLUTCH - 62640341A', 1, 1, 127, '', 3645.95, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(128, 0, 7, 'LEVER MTS1200S - GEARCHANGE - 45612041A', 'LEVER MTS1200S - GEARCHANGE - 45612041A', 1, 1, 128, '', 2522.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(129, 0, 7, 'LEVER PS/05 FRONT BRAKE - 62640411A', 'LEVER PS/05 FRONT BRAKE - 62640411A', 1, 1, 129, '', 4818.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(130, 0, 7, 'LEVER S4R/03 REAR BRAKE PEDAL - 45720181B', 'LEVER S4R/03 REAR BRAKE PEDAL - 45720181B', 1, 1, 130, '', 4348.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(131, 0, 7, 'LIQUID GASKET-THREEBOND 50GPACK-942470036', 'LIQUID GASKET-THREEBOND 50GPACK-942470036', 1, 1, 131, '', 1483.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(132, 0, 7, 'LIQUID GASKET-THREEBOND ADESIVO - 942470039', 'LIQUID GASKET-THREEBOND ADESIVO - 942470039', 1, 1, 132, '', 629.47, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(133, 0, 7, 'LIQUID GASKET-THREEBOND RESINA -942470038', 'LIQUID GASKET-THREEBOND RESINA -942470038', 1, 1, 133, '', 1200.89, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(134, 0, 7, 'LIQUID GASKET-THREEBOND RESINA-RESINA - 942470037', 'LIQUID GASKET-THREEBOND RESINA-RESINA - 942470037', 1, 1, 134, '', 1200.90, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(135, 0, 7, 'M696 TAIL LIGHT - 52510342A', 'M696 TAIL LIGHT - 52510342A', 1, 1, 135, '', 6056.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(136, 0, 7, 'M795 PEDAL BRAKE - 45720461A', 'M795 PEDAL BRAKE - 45720461A', 1, 1, 136, '', 2712.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(137, 0, 7, 'MONSTER 795 FORK OIL SEAL', 'MONSTER 795 FORK OIL SEAL', 1, 1, 137, '', 0.00, 1595.00, 1, '2015-07-31', 0, 1595.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(138, 0, 7, 'MONSTER 795 SPARE KEY - 59840341A', 'MONSTER 795 SPARE KEY - 59840341A', 1, 1, 138, '', 0.00, 3300.00, 0, '2015-07-31', 0, 3300.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(139, 0, 7, 'MIRROR - L.H. - 52310031A', 'MIRROR - L.H. - 52310031A', 1, 1, 139, '', 3738.39, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(140, 0, 7, 'MIRROR - LH REAR - 52340251A', 'MIRROR - LH REAR - 52340251A', 1, 1, 140, '', 3596.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(141, 0, 7, 'MIRROR - M696 L.H. - 52340232A', 'MIRROR - M696 L.H. - 52340232A', 1, 1, 141, '', 3596.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(142, 0, 7, 'MIRROR - M696 R.H. - 52340222A', 'MIRROR - M696 R.H. - 52340222A', 1, 1, 142, '', 3596.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(143, 0, 7, 'MIRROR - MS1200 - LH REAR - 52310341A', 'MIRROR - MS1200 - LH REAR - 52310341A', 1, 1, 143, '', 5298.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(144, 0, 7, 'MIRROR - MS1200 - RH REAR - 52310351A', 'MIRROR - MS1200 - RH REAR - 52310351A', 1, 1, 144, '', 5298.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(145, 0, 7, 'MIRROR - RH REAR - 52340241A', 'MIRROR - RH REAR - 52340241A', 1, 1, 145, '', 3596.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(146, 0, 7, 'MIRROR DUCATI LEFT - 52340231B', 'MIRROR DUCATI LEFT - 52340231B', 1, 1, 146, '', 3250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(147, 0, 7, 'MIRROR DUCATI RIGHT - 52340221B', 'MIRROR DUCATI RIGHT - 52340221B', 1, 1, 147, '', 3250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(148, 0, 7, 'MIRROR PAIR HYM - 96987208B', 'MIRROR PAIR HYM - 96987208B', 1, 1, 148, '', 12750.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(149, 0, 7, 'MONSTER S4RS IGNITION COIL - 38010143A', 'MONSTER S4RS IGNITION COIL - 38010143A', 1, 1, 149, '', 8678.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(150, 0, 7, 'MTS BULB - 12V,55W LAMP - 39040201A', 'MTS BULB - 12V,55W LAMP - 39040201A', 1, 1, 150, '', 1114.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(151, 0, 7, 'MTS1200 GAUGES FUEL LEVEL - 59210201F', 'MTS1200 GAUGES FUEL LEVEL - 59210201F', 1, 1, 151, '', 7417.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(152, 0, 7, 'MTSPP-M795 SCREW', 'MTSPP-M795 SCREW', 1, 1, 152, '', 155.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(153, 0, 7, 'NUMBERPLATE HOLDER 1098S/07 -56110251A', 'NUMBERPLATE HOLDER 1098S/07 -56110251A', 1, 1, 153, '', 1732.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(154, 0, 7, 'NUT - M6 900MHE - 74750031A', 'NUT - M6 900MHE - 74750031A', 1, 1, 154, '', 5.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(155, 0, 7, 'OIL FILTER M900-996B - OIL CATRID - 44440035A', 'OIL FILTER M900-996B - OIL CATRID - 44440035A', 1, 1, 155, '', 503.00, 1130.00, 4, '2015-07-31', 0, 1130.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(156, 0, 7, 'OIL SEAL 1098/FRONT - 34912631A', 'OIL SEAL 1098/FRONT - 34912631A', 1, 1, 156, '', 2883.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(157, 0, 7, 'OIL SEAL FORK M696/09 OIL+DUST - 34912611A', 'OIL SEAL FORK M696/09 OIL+DUST - 34912611A', 1, 1, 157, '', 3340.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(158, 0, 7, 'OIL SEALS FORK KIT HYM/08 - 34920491A', 'OIL SEALS FORK KIT HYM/08 - 34920491A', 1, 1, 158, '', 3253.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(159, 0, 7, 'OIL SEALS FORK KIT -OHLINS - 34920401A', 'OIL SEALS FORK KIT -OHLINS - 34920401A', 1, 1, 159, '', 3340.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(160, 0, 7, 'O-RING 114NBR - 88641161A', 'O-RING 114NBR - 88641161A', 1, 1, 160, '', 10.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(161, 0, 7, 'PIN PEDAL - 82111701B', 'PIN PEDAL - 82111701B', 1, 1, 161, '', 133.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(162, 0, 7, 'PINION FIXING PLATE-SPROCKET ENGINE LOCK-82610111A', 'PINION FIXING PLATE-SPROCKET ENGINE LOCK-82610111A', 1, 1, 162, '', 311.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(163, 0, 7, 'PISTON RING SET - 12120161A', 'PISTON RING SET - 12120161A', 1, 1, 163, '', 6348.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(164, 0, 7, 'PLATE RH FOOTPEG M696 - 82411441B ', 'PLATE RH FOOTPEG M696 - 82411441B ', 1, 1, 164, '', 6343.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(165, 0, 7, 'PRESSURE PLATE - BLACK - 96858708B', 'PRESSURE PLATE - BLACK - 96858708B', 1, 1, 165, '', 7620.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(166, 0, 7, 'REAR CARB FENDER - HYS - 96980211A', 'REAR CARB FENDER - HYS - 96980211A', 1, 1, 166, '', 11400.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(167, 0, 7, 'REAR FENDER - CARBON - 969A04409B-M1100', 'REAR FENDER - CARBON - 969A04409B-M1100', 1, 1, 167, '', 11430.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(168, 0, 7, 'REAR FENDER SBK CARBON - 969A03208B', 'REAR FENDER SBK CARBON - 969A03208B', 1, 1, 168, '', 7678.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(169, 0, 7, 'REGULATOR 996B-ST4-748 - 54040111C', 'REGULATOR 996B-ST4-748 - 54040111C', 1, 1, 169, '', 5455.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(170, 0, 7, 'REGULATOR 999/03 - 54040191A', 'REGULATOR 999/03 - 54040191A', 1, 1, 170, '', 4596.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(171, 0, 7, 'RELAY 1098SF - SOLENOID - 39740071A STARTER', 'RELAY 1098SF - SOLENOID - 39740071A STARTER', 1, 1, 171, '', 3633.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(172, 0, 7, 'RELAY ST4-998B-750-900M - 54140101A', 'RELAY ST4-998B-750-900M - 54140101A', 1, 1, 172, '', 198.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(173, 0, 7, 'RIGHT BRACKET M795 -82919681A', 'RIGHT BRACKET M795 -82919681A', 1, 1, 173, '', 0.00, 504.00, 0, '2015-07-31', 0, 504.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(174, 0, 7, 'ROLLER BEARING - 757941542', 'ROLLER BEARING - 757941542', 1, 1, 174, '', 1028.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(175, 0, 7, 'RUBBER BAND BATTERY - 75910241A', 'RUBBER BAND BATTERY - 75910241A', 1, 1, 175, '', 101.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(176, 0, 7, 'RUBBER BATTERY HOLDER - 82917501A', 'RUBBER BATTERY HOLDER - 82917501A', 1, 1, 176, '', 185.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(177, 0, 7, 'SCREW DUCATI - 77910921A', 'SCREW DUCATI - 77910921A', 1, 1, 177, '', 198.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(178, 0, 7, 'SCREW M5X20 - 748 - 77150438B', 'SCREW M5X20 - 748 - 77150438B', 1, 1, 178, '', 7.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(179, 0, 7, 'SCREW REARBRAKE SWITCH - 77912371B', 'SCREW REARBRAKE SWITCH - 77912371B', 1, 1, 179, '', 75.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(180, 0, 7, 'SCREW SEAT COVER/COWLING RED - 77915661B', 'SCREW SEAT COVER/COWLING RED - 77915661B', 1, 1, 180, '', 591.97, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(181, 0, 7, 'SCREW SELF TAPP - 77450131A', 'SCREW SELF TAPP - 77450131A', 1, 1, 181, '', 10.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(182, 0, 7, 'SEAL RING - DUCATI 93041231A', 'SEAL RING - DUCATI 93041231A', 1, 1, 182, '', 326.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(183, 0, 7, 'SEAT DUCATI - HYM - LOW COM -96782608B', 'SEAT DUCATI - HYM - LOW COM -96782608B', 1, 1, 183, '', 9398.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(184, 0, 7, 'SEAT DUCATI MONSTER COMFORT - 96766909B', 'SEAT DUCATI MONSTER COMFORT - 96766909B', 1, 1, 184, '', 9165.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(185, 0, 7, 'SEAT DUCATI MTS - 96784410B', 'SEAT DUCATI MTS - 96784410B', 1, 1, 185, '', 10614.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(186, 0, 7, 'SENSOR 900SS, M-WATER TEMPERATURE - 55240131A', 'SENSOR 900SS, M-WATER TEMPERATURE - 55240131A', 1, 1, 186, '', 4247.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(187, 0, 7, 'SENSOR AIR TEMPERATURE - 55240121A', 'SENSOR AIR TEMPERATURE - 55240121A', 1, 1, 187, '', 1939.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(188, 0, 7, 'SF 848 - TERMIGNONI EXHAUST PIPE SILENCER - 96454711B', 'SF 848 - TERMIGNONI EXHAUST PIPE SILENCER - 96454711B', 1, 1, 188, '', 67481.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(189, 0, 7, 'SIGNAL LIGHT - L.H 900BLINKER - 800074505', 'SIGNAL LIGHT - L.H 900BLINKER - 800074505', 1, 1, 189, '', 691.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(190, 0, 7, 'SIGNAL LIGHT - R.H BLINKER - 800074504', 'SIGNAL LIGHT - R.H BLINKER - 800074504', 1, 1, 190, '', 691.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(191, 0, 7, 'SIGNAL LIGHT - TURN INDICATOR - 96629909B-M696', 'SIGNAL LIGHT - TURN INDICATOR - 96629909B-M696', 1, 1, 191, '', 4526.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(194, 0, 7, 'SIGNAL LIGHT 749-999 RH - 53240081A', 'SIGNAL LIGHT 749-999 RH - 53240081A', 1, 1, 194, '', 1861.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(196, 0, 7, 'SIGNAL LIGHT HYM1100 LH-REAR - 53010174A', 'SIGNAL LIGHT HYM1100 LH-REAR - 53010174A', 1, 1, 196, '', 1237.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(197, 0, 7, 'SIGNAL LIGHT HYM1100 RH-REAR - 53010164A', 'SIGNAL LIGHT HYM1100 RH-REAR - 53010164A', 1, 1, 197, '', 1237.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(198, 0, 7, 'SIGNAL LIGHT LH GLASS - 749-999 B/03 - 53240091A', 'SIGNAL LIGHT LH GLASS - 749-999 B/03 - 53240091A', 1, 1, 198, '', 1861.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(203, 0, 7, 'SIGNAL LIGHT SF1098/10 FRONT LH-RE - 53010224A', 'SIGNAL LIGHT SF1098/10 FRONT LH-RE - 53010224A', 1, 1, 203, '', 1145.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(204, 0, 7, 'SIGNAL LIGHT SF1098/10 FRONT RH-RE - 53010234A', 'SIGNAL LIGHT SF1098/10 FRONT RH-RE - 53010234A', 1, 1, 204, '', 1145.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(205, 0, 7, 'SILENT BLOCK - 620/750 RUBBER BUSH - 70010491A', 'SILENT BLOCK - 620/750 RUBBER BUSH - 70010491A', 1, 1, 205, '', 37.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(206, 0, 7, 'SPARKPLUG 67040381A - MAR10A-J', 'SPARKPLUG 67040381A - MAR10A-J', 1, 1, 206, '', 1133.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(207, 0, 7, 'SPARKPLUG 67090081A - 900-750M', 'SPARKPLUG 67090081A - 900-750M', 1, 1, 207, '', 297.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(208, 0, 7, 'SPARKPLUG 600M,ST2 RA4HC 67090071A', 'SPARKPLUG 600M,ST2 RA4HC 67090071A', 1, 1, 208, '', 297.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(211, 0, 7, 'SPARKPLUG 996-748- RA59GC - 67090121A', 'SPARKPLUG 996-748- RA59GC - 67090121A', 1, 1, 211, '', 1045.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(212, 0, 7, 'SPARKPLUG NGK 10/BOX -NG4339 - DCPR8E', 'SPARKPLUG NGK 10/BOX -NG4339 - DCPR8E', 1, 1, 212, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(213, 0, 7, 'SPARKPLUG NGK CR9E', 'SPARKPLUG NGK CR9E', 1, 1, 213, '', 250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(214, 0, 7, 'SPARKPLUG NGK-MAR9A-J 67040451A NGK', 'SPARKPLUG NGK-MAR9A-J 67040451A NGK', 1, 1, 214, '', 1117.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(215, 0, 7, 'SPARKPLUG S2R/05-620-MTS/06 - 67090331A', 'SPARKPLUG S2R/05-620-MTS/06 - 67090331A', 1, 1, 215, '', 297.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(216, 0, 7, 'SPARKPLUG 620-MTS/06 DCPR8E- 67040351A', 'SPARKPLUG 620-MTS/06 DCPR8E- 67040351A', 1, 1, 216, '', 0.00, 1215.50, 0, '2015-07-31', 0, 1215.50, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(284, 0, 2, 'FOOT BRAKE LEVER KIT - 90113050133', 'FOOT BRAKE LEVER KIT - 90113050133', 1, 1, 284, '', 2750.00, 4755.00, 0, '2015-07-31', 0, 4755.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(285, 0, 2, 'REAR SPROCKET 42-T KTM DUKE 390 ANODIZED ORANGE - 023784', 'REAR SPROCKET 42-T KTM DUKE 390 ANODIZED ORANGE - 023784', 1, 1, 285, '', 2750.00, 4755.00, 0, '2015-07-31', 0, 4755.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(286, 0, 2, 'CHAIN KTM ORANGE 520 - 021989', 'CHAIN KTM ORANGE 520 - 021989', 1, 1, 286, '', 1669.50, 2885.00, 0, '2015-07-31', 0, 2885.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(287, 0, 2, 'TAILY TIDY W/ INTEGRATED TAIL LIGHT KTM DUKE 200/390 - 023791', 'TAILY TIDY W/ INTEGRATED TAIL LIGHT KTM DUKE 200/390 - 023791', 1, 1, 287, '', 7300.00, 12595.00, 0, '2015-07-31', 0, 12595.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(288, 0, 2, 'FOOT PEG KTM DUKE 200/390 - 023785', 'FOOT PEG KTM DUKE 200/390 - 023785', 1, 1, 288, '', 2035.00, 3520.00, 0, '2015-07-31', 0, 3520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(289, 0, 2, 'KTM REAR SPROCKET 38T - 58310051038', 'KTM REAR SPROCKET 38T - 58310051038', 1, 1, 289, '', 0.00, 4180.00, 0, '2015-07-31', 0, 4180.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(290, 0, 2, 'AKRAPOVIC PIPE FOR KTM DUKE 200 - 90505999000', 'AKRAPOVIC PIPE FOR KTM DUKE 200 - 90505999000', 1, 9, 290, '', 0.00, 37000.00, 0, '2015-07-31', 0, 37000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(291, 0, 2, 'KTM RADIATOR FAN - 90135041133', 'KTM RADIATOR FAN - 90135041133', 1, 9, 291, '', 4130.00, 6400.00, 2, '2015-07-31', 0, 6400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(292, 0, 2, 'BIKERS REAR FOOTREST KTM DUKE 200', 'BIKERS REAR FOOTREST KTM DUKE 200', 1, 9, 292, '', 8500.00, 14665.00, 1, '2015-07-31', 0, 14665.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(293, 0, 2, 'BIKERS FOLDING ADJUSTABLE BRAKE LEVER KTM D200/D390', 'BIKERS FOLDING ADJUSTABLE BRAKE LEVER KTM D200/D390', 1, 9, 293, '', 0.00, 7420.00, 0, '2015-07-31', 0, 7420.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(294, 0, 2, 'FUEL PUMP MODULE - 90107088000', 'FUEL PUMP MODULE - 90107088000', 1, 1, 294, '', 0.00, 13530.00, 0, '2015-07-31', 0, 13530.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(295, 0, 2, 'CHAIN ADJUSTER SLIDER KTM DUKE 200/390 - 022581', 'CHAIN ADJUSTER SLIDER KTM DUKE 200/390 - 022581', 1, 1, 295, '', 1225.00, 2145.00, 3, '2015-07-31', 0, 2145.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(296, 0, 2, 'FRONT FENDER SLIDER KTM DUKE - 022603', 'FRONT FENDER SLIDER KTM DUKE - 022603', 1, 1, 296, '', 295.00, 520.00, 1, '2015-07-31', 0, 520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(297, 0, 2, 'KTM DUKE 390 SIGNAL LIGHT RH - 90114025000', 'KTM DUKE 390 SIGNAL LIGHT RH - 90114025000', 1, 1, 297, '', 0.00, 3080.00, 1, '2015-07-31', 0, 3080.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(298, 0, 2, 'KTM DUKE 390 SIGNAL LIGHT LH - 90114126000', 'KTM DUKE 390 SIGNAL LIGHT LH - 90114126000', 1, 1, 298, '', 0.00, 3080.00, 1, '2015-07-31', 0, 3080.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(299, 0, 2, 'ADV 1190 ORANGE CRASH BAR', 'ADV 1190 ORANGE CRASH BAR', 1, 1, 299, '', 19800.00, 24750.00, 0, '2015-07-31', 0, 24750.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(300, 0, 2, 'ECU', 'ECU', 1, 1, 300, '', 18200.00, 25480.00, 0, '2015-07-31', 0, 25480.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(301, 0, 2, 'PUSH ROD CPL. 50302046000', 'PUSH ROD CPL. 50302046000', 1, 1, 301, '', 0.00, 1400.00, 0, '2015-07-31', 0, 1400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(302, 0, 2, 'CAMPSHAFT EXHAUST 77336010444', 'CAMPSHAFT EXHAUST 77336010444', 1, 1, 302, '', 0.00, 14200.00, 0, '2015-07-31', 0, 14200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(303, 0, 2, 'KIT KTM GEAR CHANGE LEVER - 90134031133', 'KIT KTM GEAR CHANGE LEVER - 90134031133', 1, 1, 303, '', 1020.00, 1500.00, 0, '2015-07-31', 0, 1500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(304, 0, 2, 'AIR FILTR EFI - 6100601500', 'AIR FILTR EFI - 6100601500', 1, 1, 304, '', 0.00, 2640.00, 1, '2015-07-31', 0, 2640.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(305, 0, 2, 'AIR FILTER - 77206015000', 'AIR FILTER - 77206015000', 1, 1, 305, '', 0.00, 2090.00, 1, '2015-07-31', 0, 2090.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(306, 0, 2, 'LEVER SET ADJUSTABLE KTM D200 BLACK - 021884', 'LEVER SET ADJUSTABLE KTM D200 BLACK - 021884', 1, 1, 306, '', 2415.00, 4400.00, 2, '2015-07-31', 0, 4400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(307, 0, 2, 'LEVER SET ADJUSTABLE KTM D200 ORANGE *021884', 'LEVER SET ADJUSTABLE KTM D200 ORANGE *021884', 1, 1, 307, '', 2415.00, 4400.00, 11, '2015-07-31', 0, 4400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(308, 0, 2, 'RADIATOR HOSE KIT KTM D200 ORANGE *021986', 'RADIATOR HOSE KIT KTM D200 ORANGE *021986', 1, 9, 308, '', 0.00, 2420.00, 0, '2015-07-31', 0, 2420.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(309, 0, 2, 'RADIATOR HOSE KIT KTM D390 ORANGE *021987', 'RADIATOR HOSE KIT KTM D390 ORANGE *021987', 1, 9, 309, '', 0.00, 2420.00, 1, '2015-07-31', 0, 2420.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(310, 0, 2, 'SWING ARM SPOOLS KTM DUKE 200/390 - 021973', 'SWING ARM SPOOLS KTM DUKE 200/390 - 021973', 1, 9, 310, '', 644.00, 1115.00, 1, '2015-07-31', 0, 1115.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(311, 0, 2, 'HANDLE BAR CLAMP KTM DUKE 200/390 - 021978', 'HANDLE BAR CLAMP KTM DUKE 200/390 - 021978', 1, 9, 311, '', 1085.00, 2055.00, 1, '2015-07-31', 0, 2055.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(312, 0, 2, 'HANDLE BAR KTM DUKE 200/390 GREY - 021977', 'HANDLE BAR KTM DUKE 200/390 GREY - 021977', 1, 9, 312, '', 1085.00, 2055.00, 0, '2015-07-31', 0, 2055.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(313, 0, 2, 'HANDLE BAR KTM DUKE 200/390 ORANGE - 021976', 'HANDLE BAR KTM DUKE 200/390 ORANGE - 021976', 1, 9, 313, '', 1085.00, 2055.00, 0, '2015-07-31', 0, 2055.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(314, 0, 2, 'RADIATOR GRILL KTM DUKE 200 (D-001) ORANGE *021990', 'RADIATOR GRILL KTM DUKE 200 (D-001) ORANGE *021990', 1, 1, 314, '', 1382.50, 2420.00, 3, '2015-07-31', 0, 2420.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(315, 0, 2, 'RADIATOR GRILL KTM DUKE 390 (D-002) SILVER *021990', 'RADIATOR GRILL KTM DUKE 390 (D-002) SILVER *021990', 1, 1, 315, '', 1382.50, 2420.00, 2, '2015-07-31', 0, 2420.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(316, 0, 2, 'KTM TANK PAD - 90107011000', 'KTM TANK PAD - 90107011000', 1, 1, 316, '', 0.00, 1540.00, 2, '2015-07-31', 0, 1540.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(317, 0, 2, 'TANK CAP PAD KTM DUKE 200/390 - 023787', 'TANK CAP PAD KTM DUKE 200/390 - 023787', 1, 1, 317, '', 295.00, 520.00, 0, '2015-07-31', 0, 520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(318, 0, 2, 'TANK PROTECTOR PAD KTM ORANGE - 021975', 'TANK PROTECTOR PAD KTM ORANGE - 021975', 1, 1, 318, '', 385.00, 730.00, 2, '2015-07-31', 0, 730.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(319, 0, 2, 'TANK PROTECTOR PAD KTM BLACK - 021974', 'TANK PROTECTOR PAD KTM BLACK - 021974', 1, 1, 319, '', 385.00, 730.00, 1, '2015-07-31', 0, 730.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(320, 0, 2, 'KTM WINDSCREED EXTEND DUKE 125/200/390 *021993', 'KTM WINDSCREED EXTEND DUKE 125/200/390 *021993', 1, 1, 320, '', 0.00, 1320.00, 3, '2015-07-31', 0, 1320.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(321, 0, 2, 'KTM WINDSCREEN EXTENDED - KTM DUKE 200/390', 'KTM WINDSCREEN EXTENDED - KTM DUKE 200/390', 1, 1, 321, '', 0.00, 1190.00, 1, '2015-07-31', 0, 1190.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(322, 0, 2, 'KTM DUKE 200/390 GAS TANK CAP ', 'KTM DUKE 200/390 GAS TANK CAP ', 1, 1, 322, '', 803.57, 4394.50, 2, '2015-07-31', 0, 4394.50, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(324, 0, 2, 'KTM GAS TANK CAP 2-TONE D200/390 *021970', 'KTM GAS TANK CAP 2-TONE D200/390 *021970', 1, 1, 324, '', 0.00, 3280.00, 2, '2015-07-31', 0, 3280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(325, 0, 2, 'KTM ENGINE SPROCKET COVER CNC DUKE 200 *021069', 'KTM ENGINE SPROCKET COVER CNC DUKE 200 *021069', 1, 1, 325, '', 0.00, 2520.00, 1, '2015-07-31', 0, 2520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(326, 0, 2, 'KTM ENGINE SPROCKET COVER CNC DUKE 390 *021988', 'KTM ENGINE SPROCKET COVER CNC DUKE 390 *021988', 1, 1, 326, '', 0.00, 2520.00, 1, '2015-07-31', 0, 2520.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(327, 0, 2, 'PEDAL SET CNC KTM D200 NON-ABS (ORANGE) *021982', 'PEDAL SET CNC KTM D200 NON-ABS (ORANGE) *021982', 1, 1, 327, '', 2275.00, 4115.00, 3, '2015-07-31', 0, 4115.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(329, 0, 2, 'PEDAL SET CNC KTM D200/390 ABS (ORANGE) *021981', 'PEDAL SET CNC KTM D200/390 ABS (ORANGE) *021981', 1, 1, 329, '', 2275.00, 4125.00, 11, '2015-07-31', 0, 4125.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(331, 0, 2, 'KTM BRAKE LEVER / GEAR LEVER - 021981', 'KTM BRAKE LEVER / GEAR LEVER - 021981', 1, 1, 331, '', 0.00, 4125.00, 1, '2015-07-31', 0, 4125.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(332, 0, 2, 'OIL FILTER COVER KTM D200/390 *021615', 'OIL FILTER COVER KTM D200/390 *021615', 1, 1, 332, '', 700.00, 1335.00, 7, '2015-07-31', 0, 1335.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(333, 0, 2, 'FRAME SLIDER KTM D200/390 (BLACK) - 021971', 'FRAME SLIDER KTM D200/390 (BLACK) - 021971', 1, 9, 333, '', 2920.00, 5040.00, 3, '2015-07-31', 0, 5040.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(334, 0, 2, 'FRAME SLIDER KTM D200/390 (ORANGE) - 021972', 'FRAME SLIDER KTM D200/390 (ORANGE) - 021972', 1, 9, 334, '', 2920.00, 5040.00, 6, '2015-07-31', 0, 5040.00, '2015-12-09', 'BRANDNEW', 3, '', '', '_', 0),
	(335, 0, 2, 'FRAME SLIDER KTM D200/390 (ORANGE/BLACK)', 'FRAME SLIDER KTM D200/390 (ORANGE/BLACK)', 1, 9, 335, '', 0.00, 5040.00, 0, '2015-07-31', 0, 5040.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(336, 0, 2, 'CRASH GUARD KTM DUKE 200 ORANGE W/ SLIDER - 021984', 'CRASH GUARD KTM DUKE 200 ORANGE W/ SLIDER - 021984', 1, 9, 336, '', 0.00, 7590.00, 1, '2015-07-31', 0, 7590.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(337, 0, 2, 'CRASH GUARD D200 (BLACK)', 'CRASH GUARD D200 (BLACK)', 1, 9, 337, '', 0.00, 7755.00, 3, '2015-07-31', 0, 7755.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(338, 0, 2, 'CRASH GUARD D390 (ORANGE)', 'CRASH GUARD D390 (ORANGE)', 1, 9, 338, '', 0.00, 7755.00, 5, '2015-07-31', 0, 7755.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(339, 0, 2, 'BRAKE PAD SET REAR-TOYO - 54813090300', 'BRAKE PAD SET REAR-TOYO - 54813090300', 1, 1, 339, '', 2799.11, 4478.00, 1, '2015-07-31', 0, 4478.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(340, 0, 2, 'BRAKE PAD TT2701HH-FRONT SET - 50313030200', 'BRAKE PAD TT2701HH-FRONT SET - 50313030200', 1, 1, 340, '', 3017.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(341, 0, 2, 'BRAKE PADS REAR 85SX 2011 - 47013090300', 'BRAKE PADS REAR 85SX 2011 - 47013090300', 1, 1, 341, '', 1566.97, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(342, 0, 2, 'BRAKE PUMP REAR BRAKE CYL.DUKE200 - 90113060000', 'BRAKE PUMP REAR BRAKE CYL.DUKE200 - 90113060000', 1, 1, 342, '', 1607.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(343, 0, 2, 'BRAKEPAD FRONT 1190 - 60313130000', 'BRAKEPAD FRONT 1190 - 60313130000', 1, 1, 343, '', 3500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(344, 0, 2, 'BRAKEPAD FRONT SET 1190 - 50313030000', 'BRAKEPAD FRONT SET 1190 - 50313030000', 1, 1, 344, '', 2571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(345, 0, 2, 'BRAKEPAD SET 50-SX - 45113030000', 'BRAKEPAD SET 50-SX - 45113030000', 1, 9, 345, '', 1191.22, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(346, 0, 2, 'BRAKEPAD SET FRONT - DUKE200 - 90113030000', 'BRAKEPAD SET FRONT - DUKE200 - 90113030000', 1, 9, 346, '', 910.71, 1870.00, 2, '2015-07-31', 0, 1870.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(347, 0, 2, 'BULB - H4 KTM DUKE200 - 57111038000', 'BULB - H4 KTM DUKE200 - 57111038000', 1, 1, 347, '', 571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(348, 0, 2, 'CABLE CLUTCH 200 EXC - 60032063100', 'CABLE CLUTCH 200 EXC - 60032063100', 1, 1, 348, '', 2553.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(349, 0, 2, 'CABLE DIGITAL SPEEDOM - 58314069251', 'CABLE DIGITAL SPEEDOM - 58314069251', 1, 1, 349, '', 2400.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(350, 0, 2, 'CABLE THROTTLE - 77002091000-250 SX-F', 'CABLE THROTTLE - 77002091000-250 SX-F', 1, 1, 350, '', 1928.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(351, 0, 2, 'CABLE THROTTLE - D200 - 90102091000', 'CABLE THROTTLE - D200 - 90102091000', 1, 1, 351, '', 642.86, 1430.00, 5, '2015-07-31', 0, 1430.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(352, 0, 2, 'CABLE THROTTLE CLUTCH - D200 - 90102090000', 'CABLE THROTTLE CLUTCH - D200 - 90102090000', 1, 1, 352, '', 830.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(353, 0, 2, 'CARRIERS QUICKLOCK SYSTEM - PLASTIC CASE 60112020100 ', 'CARRIERS QUICKLOCK SYSTEM - PLASTIC CASE 60112020100 ', 1, 9, 353, '', 12285.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(354, 0, 2, 'CHAIN 1/2X1/4" 65 SX - 46110165112', 'CHAIN 1/2X1/4" 65 SX - 46110165112', 1, 1, 354, '', 1276.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(355, 0, 2, 'CHAIN 108ROLLS/TIMING CHAIN - 77036013100', 'CHAIN 108ROLLS/TIMING CHAIN - 77036013100', 1, 1, 355, '', 1946.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(356, 0, 2, 'CHAIN ADJUSTER 250SX-F - 77036003000', 'CHAIN ADJUSTER 250SX-F - 77036003000', 1, 1, 356, '', 1857.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(357, 0, 2, 'CHAIN GUARD - 50304066100', 'CHAIN GUARD - 50304066100', 1, 1, 357, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(358, 0, 2, 'CHAIN KTM - 118 ROLLS DID - 78010167118', 'CHAIN KTM - 118 ROLLS DID - 78010167118', 1, 1, 358, '', 4514.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(359, 0, 2, 'BREMBO REAR PAD SET PAD 1190 - 50313030000', 'BREMBO REAR PAD SET PAD 1190 - 50313030000', 1, 1, 359, '', 0.00, 3600.00, 0, '2015-07-31', 0, 3600.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(361, 0, 2, 'CABLE CLUTCH - D200 - 90102090000', 'CABLE CLUTCH - D200 - 90102090000', 1, 1, 361, '', 830.36, 2090.00, 3, '2015-07-31', 0, 2090.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(362, 0, 2, 'CHAIN KTM 520X 118 ORANGE Z-RING - 5031080011804', 'CHAIN KTM 520X 118 ORANGE Z-RING - 5031080011804', 1, 1, 362, '', 5223.21, 8580.00, 3, '2015-07-31', 0, 8580.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(363, 0, 2, 'CHAIN KTM LINK 6.35 PITCH - 6003601300-88', 'CHAIN KTM LINK 6.35 PITCH - 6003601300-88', 1, 1, 363, '', 2741.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(364, 0, 2, 'CHAIN MX 520-118 LINKS - 50310165118', 'CHAIN MX 520-118 LINKS - 50310165118', 1, 1, 364, '', 3000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(365, 0, 2, 'CHAIN SPROCKET 14-T. - 46233029014', 'CHAIN SPROCKET 14-T. - 46233029014', 1, 1, 365, '', 696.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(366, 0, 2, 'CHAIN TENSIONER R/S - 60010084000', 'CHAIN TENSIONER R/S - 60010084000', 1, 1, 366, '', 750.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(367, 0, 2, 'CLAMP 25-40 SGT 4 - 10001120000', 'CLAMP 25-40 SGT 4 - 10001120000', 1, 1, 367, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(368, 0, 2, 'CLUTCH COVER HYDRAULIC - SXS05450220', 'CLUTCH COVER HYDRAULIC - SXS05450220', 1, 1, 368, '', 1092.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(369, 0, 2, 'CLUTCH KIT 105/85 SX 03-14 - 47032010010', 'CLUTCH KIT 105/85 SX 03-14 - 47032010010', 1, 1, 369, '', 5517.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(370, 0, 2, 'CLUTCH OUTSIDE COVER CPL 06', 'CLUTCH OUTSIDE COVER CPL 06', 1, 1, 370, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(372, 0, 2, 'CLUTCH PLATE - LINING DISCTURNED DUKE200-90132211000', 'CLUTCH PLATE - LINING DISCTURNED DUKE200-90132211000', 1, 1, 372, '', 535.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(373, 0, 2, 'CLUTCH PLATE INTERMEDI DISC LINING - 90132010000', 'CLUTCH PLATE INTERMEDI DISC LINING - 90132010000', 1, 1, 373, '', 257.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(374, 0, 2, 'CLUTCH PLATE LINING DISC-2MM-59032011100', 'CLUTCH PLATE LINING DISC-2MM-59032011100', 1, 1, 374, '', 522.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(375, 0, 2, 'CLUTCH PLATE LINING DISK - 90132011000', 'CLUTCH PLATE LINING DISK - 90132011000', 1, 1, 375, '', 369.90, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(376, 0, 2, 'CLUTH LEVER LONG 1190 - 60302031000', 'CLUTH LEVER LONG 1190 - 60302031000', 1, 1, 376, '', 2437.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(377, 0, 2, 'COLLAR NUT WHEEL SPINDLE REAR - 90110086000', 'COLLAR NUT WHEEL SPINDLE REAR - 90110086000', 1, 1, 377, '', 160.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(378, 0, 2, 'CONNECT.ROD REPAIR SET 85 SX - 47030015200', 'CONNECT.ROD REPAIR SET 85 SX - 47030015200', 1, 1, 378, '', 12803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(379, 0, 2, 'CONNECTING ROD - 50SX - 45130015000', 'CONNECTING ROD - 50SX - 45130015000', 1, 1, 379, '', 3107.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(380, 0, 2, 'CONNECTOR SPARKPLUG - 77239090000', 'CONNECTOR SPARKPLUG - 77239090000', 1, 1, 380, '', 642.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(381, 0, 2, 'CONTROL SLIDE CPL - 65SX - 46237020144', 'CONTROL SLIDE CPL - 65SX - 46237020144', 1, 1, 381, '', 1392.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(382, 0, 2, 'COVER ALU.BRAKE FLUID RESERVOIR-61013009100', 'COVER ALU.BRAKE FLUID RESERVOIR-61013009100', 1, 1, 382, '', 1937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(383, 0, 2, 'KTM CHAIN GREY 78010167118', 'KTM CHAIN GREY 78010167118', 1, 1, 383, '', 0.00, 6515.00, 2, '2015-07-31', 0, 6515.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(384, 0, 2, 'COVER CHAIN GUARD STAINL.STEEL - 90104960044', 'COVER CHAIN GUARD STAINL.STEEL - 90104960044', 1, 1, 384, '', 2216.07, 3400.00, 3, '2015-07-31', 0, 3400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(385, 0, 2, 'COVER CHAIN TENSIONER - R/S DUKE200 - 90110084000', 'COVER CHAIN TENSIONER - R/S DUKE200 - 90110084000', 1, 1, 385, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(386, 0, 2, 'COVER FRONT BRAKE RESERVOIR - 690-58613003100', 'COVER FRONT BRAKE RESERVOIR - 690-58613003100', 1, 1, 386, '', 2075.89, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(387, 0, 2, 'COVER HANDBRAKE CYLINDER-76513903000', 'COVER HANDBRAKE CYLINDER-76513903000', 1, 1, 387, '', 2075.89, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(388, 0, 2, 'COVER KTM CAP OIL FILTER - 75038041100 -690/1190', 'COVER KTM CAP OIL FILTER - 75038041100 -690/1190', 1, 1, 388, '', 1221.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(389, 0, 2, 'COVER OIL PLUG-MACHINED - SXS05450200', 'COVER OIL PLUG-MACHINED - SXS05450200', 1, 1, 389, '', 787.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(390, 0, 2, 'COVER RADIATOR CAP - 90135016000', 'COVER RADIATOR CAP - 90135016000', 1, 1, 390, '', 910.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(391, 0, 2, 'COVER SIDE TOP L/S DUKE200 - 90108041000', 'COVER SIDE TOP L/S DUKE200 - 90108041000', 1, 1, 391, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(392, 0, 2, 'COVER SIDE TOP R/S DUKE200 - 90108042000', 'COVER SIDE TOP R/S DUKE200 - 90108042000', 1, 1, 392, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(393, 0, 2, 'CRANKSHAFT REP.KIT 85/105 SX - 00050002307', 'CRANKSHAFT REP.KIT 85/105 SX - 00050002307', 1, 1, 393, '', 3075.89, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(394, 0, 2, 'CRASHBAR SET BLACK 1190 - 6031296814433', 'CRASHBAR SET BLACK 1190 - 6031296814433', 1, 1, 394, '', 12000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(395, 0, 2, 'CRASHGUARD ORANGE 1190 - 6031296804404', 'CRASHGUARD ORANGE 1190 - 6031296804404', 1, 1, 395, '', 12000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(397, 0, 2, 'CYLINDER - OUTPUT-CYLINDER - 59032061044', 'CYLINDER - OUTPUT-CYLINDER - 59032061044', 1, 1, 397, '', 4745.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(398, 0, 2, 'D200 - GEAR SHIFTER LEVER - 90134031133', 'D200 - GEAR SHIFTER LEVER - 90134031133', 1, 1, 398, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(399, 0, 2, 'DAMPING RUBBER SILENT BLOCK - 90110059000', 'DAMPING RUBBER SILENT BLOCK - 90110059000', 1, 1, 399, '', 321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(400, 0, 2, 'DECAL KIT ORANGE 2012 - 90608099000', 'DECAL KIT ORANGE 2012 - 90608099000', 1, 1, 400, '', 1607.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(401, 0, 2, 'DECAL SET 990 SM-R 09', 'DECAL SET 990 SM-R 09', 1, 1, 401, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(402, 0, 2, 'DISC BRAKE KTM FRONT - 90109960000', 'DISC BRAKE KTM FRONT - 90109960000', 1, 1, 402, '', 9040.18, 14850.00, 2, '2015-07-31', 0, 14850.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(403, 0, 2, 'DUKE 200 AIR FILTER - 90106015000', 'DUKE 200 AIR FILTER - 90106015000', 1, 1, 403, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(404, 0, 2, 'DUKE 200 FORK LEG CPL. R/S - 90101002000 - non ABS', 'DUKE 200 FORK LEG CPL. R/S - 90101002000 - non ABS', 1, 1, 404, '', 14000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(405, 0, 2, 'DUKE 200 LEVER FOOT BRAKE CPL - 90113050033', 'DUKE 200 LEVER FOOT BRAKE CPL - 90113050033', 1, 1, 405, '', 1339.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(406, 0, 2, 'DUKE 200 OIL DRAIN PLUG - 90138015050', 'DUKE 200 OIL DRAIN PLUG - 90138015050', 1, 1, 406, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(407, 0, 2, 'DUKE 200 SPARKPLUG VR5NE - 90139093100 ', 'DUKE 200 SPARKPLUG VR5NE - 90139093100 ', 1, 1, 407, '', 696.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(408, 0, 2, 'DUKE200  SHAFTSEAL RING 30x47x8 - J760304708', 'DUKE200  SHAFTSEAL RING 30x47x8 - J760304708', 1, 1, 408, '', 107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(409, 0, 2, 'DUKE200 CYLINDER & PISTON KIT - 90630038000', 'DUKE200 CYLINDER & PISTON KIT - 90630038000', 1, 1, 409, '', 14571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(410, 0, 2, 'DUKE200 CYLINDER BASE GASKET - 90130035000', 'DUKE200 CYLINDER BASE GASKET - 90130035000', 1, 1, 410, '', 160.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(411, 0, 2, 'DUKE200 CYLINDER HEAD GASKET - 90630036000', 'DUKE200 CYLINDER HEAD GASKET - 90630036000', 1, 1, 411, '', 642.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(412, 0, 2, 'DUKE200 GASKET CHAIN ADJUSTER - 90136003003', 'DUKE200 GASKET CHAIN ADJUSTER - 90136003003', 1, 1, 412, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(413, 0, 2, 'DUKE200 GASKET CLUTCH COVER - 90130027000', 'DUKE200 GASKET CLUTCH COVER - 90130027000', 1, 1, 413, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(414, 0, 2, 'DUKE200 IGNITION COVER GASKET - 9013004000', 'DUKE200 IGNITION COVER GASKET - 9013004000', 1, 1, 414, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(415, 0, 2, 'DUKE200 SIDE STAND - 90103023000', 'DUKE200 SIDE STAND - 90103023000', 1, 1, 415, '', 1071.43, 1430.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'NDC-TMP', 4),
	(416, 0, 2, 'DUKE200 SPACER SLEEVE - 90134031003', 'DUKE200 SPACER SLEEVE - 90134031003', 1, 1, 416, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(417, 0, 2, 'DUKE200 STATOR CPL. - 90139004000', 'DUKE200 STATOR CPL. - 90139004000', 1, 1, 417, '', 4660.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(418, 0, 2, 'ENGINE OIL CAP', 'ENGINE OIL CAP', 1, 1, 418, '', 0.00, 1240.00, 0, '2015-07-31', 0, 1240.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(419, 0, 2, 'ENGINE GUARD SET', 'ENGINE GUARD SET', 1, 9, 419, '', 0.00, 14350.00, 0, '2015-07-31', 0, 14350.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(420, 0, 2, 'ENGINE SPROCKET COVER', 'ENGINE SPROCKET COVER', 1, 1, 420, '', 0.00, 5440.00, 0, '2015-07-31', 0, 5440.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(421, 0, 2, 'EXPANSION RESERVOIR/TANK - 90135065033', 'EXPANSION RESERVOIR/TANK - 90135065033', 1, 1, 421, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(422, 0, 2, 'FENDER REAR 65 SX - 4620801300028', 'FENDER REAR 65 SX - 4620801300028', 1, 1, 422, '', 1125.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(423, 0, 2, 'FILTER KIT KTM - 81207090000 ', 'FILTER KIT KTM - 81207090000 ', 1, 1, 423, '', 2185.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(424, 0, 2, 'FLAPPER MEMBRANE - 46230052000', 'FLAPPER MEMBRANE - 46230052000', 1, 1, 424, '', 2678.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(425, 0, 2, 'FLASHER CPL. FR.LS/REAR R/S - 76014025000', 'FLASHER CPL. FR.LS/REAR R/S - 76014025000', 1, 1, 425, '', 1392.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(426, 0, 2, 'FLYWHEEL - 45039005000', 'FLYWHEEL - 45039005000', 1, 1, 426, '', 5687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(427, 0, 2, 'FOOT BRAKE LEVER CPL 07', 'FOOT BRAKE LEVER CPL 07', 1, 1, 427, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(428, 0, 2, 'FOOT-BRAKE CYL. COVER RC8 - 69013962000', 'FOOT-BRAKE CYL. COVER RC8 - 69013962000', 1, 1, 428, '', 1125.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(429, 0, 2, 'FOOTPEGS L/S+R/S CPL - 78003040033', 'FOOTPEGS L/S+R/S CPL - 78003040033', 1, 1, 429, '', 3562.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(430, 0, 2, 'FOOTPEGS L+R CPL - 5030314013390 SMT 990', 'FOOTPEGS L+R CPL - 5030314013390 SMT 990', 1, 1, 430, '', 4071.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(431, 0, 2, 'FOOTPEGS L+R CPL - SX 4700304003390', 'FOOTPEGS L+R CPL - SX 4700304003390', 1, 1, 431, '', 2892.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(432, 0, 2, 'FOOTPEGS RALLY SET 1190 - 60103940000', 'FOOTPEGS RALLY SET 1190 - 60103940000', 1, 1, 432, '', 6897.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(433, 0, 2, 'FOOTREST 990 S. DUKE L/R - 60003040033', 'FOOTREST 990 S. DUKE L/R - 60003040033', 1, 1, 433, '', 4071.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(434, 0, 2, 'FOOTREST FRONT L/S CPL DUKE200 - 90103040033', 'FOOTREST FRONT L/S CPL DUKE200 - 90103040033', 1, 1, 434, '', 482.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(435, 0, 2, 'FOOTREST FRONT R/S CPL DUKE200 - 90103041033', 'FOOTREST FRONT R/S CPL DUKE200 - 90103041033', 1, 1, 435, '', 482.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(436, 0, 2, 'FOOTREST REAR - L/S CPL DUKE200 - 90103050033', 'FOOTREST REAR - L/S CPL DUKE200 - 90103050033', 1, 1, 436, '', 482.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(437, 0, 2, 'FOOTREST REAR - R/S CPL DUKE200 - 90103051033', 'FOOTREST REAR - R/S CPL DUKE200 - 90103051033', 1, 1, 437, '', 482.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(438, 0, 2, 'FOOTREST CRACKET REAR R/S 07', 'FOOTREST CRACKET REAR R/S 07', 1, 1, 438, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(439, 0, 2, 'FOOTREST CPL R/S REAR 03', 'FOOTREST CPL R/S REAR 03', 1, 1, 439, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(440, 0, 2, 'ELEMENT FILTER - 90106015000', 'ELEMENT FILTER - 90106015000', 1, 1, 440, '', 589.29, 1320.00, 4, '2015-07-31', 0, 1320.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(441, 0, 2, 'FORK OIL SEAL - DUKE200 - 43570623', 'FORK OIL SEAL - DUKE200 - 43570623', 1, 1, 441, '', 535.71, 825.00, 2, '2015-07-31', 0, 1100.00, '2015-07-31', 'BRANDNEW', 3, '43570623', '', 'NDC-TMP', 4),
	(442, 0, 2, 'FORK SEAL RING - 48600399', 'FORK SEAL RING - 48600399', 1, 1, 442, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(443, 0, 2, 'FRONT BRAKE MASTER COVER KTM DUKE 200/390 - 021617', 'FRONT BRAKE MASTER COVER KTM DUKE 200/390 - 021617', 1, 1, 443, '', 647.00, 1115.00, 1, '2015-07-31', 0, 1115.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(444, 0, 2, 'REAR BRAKE MASTER RESERVOIR CAP KTM DUKE 200', 'REAR BRAKE MASTER RESERVOIR CAP KTM DUKE 200', 1, 1, 444, '', 0.00, 1210.00, 2, '2015-07-31', 0, 1210.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(445, 0, 2, 'FRONT FENDER BLK MATT', 'FRONT FENDER BLK MATT', 1, 1, 445, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(446, 0, 2, 'FRONT WHEEL CPL - 90109001044', 'FRONT WHEEL CPL - 90109001044', 1, 1, 446, '', 8464.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(447, 0, 2, 'FRONT WHEEL CPL BLK SD-R II', 'FRONT WHEEL CPL BLK SD-R II', 1, 1, 447, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(448, 0, 2, 'FRONT WHEEL SLIDER ', 'FRONT WHEEL SLIDER ', 1, 1, 448, '', 0.00, 5195.00, 0, '2015-07-31', 0, 5195.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(449, 0, 2, 'FUEL FILTER DUKE 200 - 90107018000', 'FUEL FILTER DUKE 200 - 90107018000', 1, 1, 449, '', 428.57, 990.00, 3, '2015-07-31', 0, 990.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(450, 0, 2, 'FUEL FILTER DUKE-KIT - 75007090000', 'FUEL FILTER DUKE-KIT - 75007090000', 1, 1, 450, '', 2167.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(451, 0, 2, 'FUEL FILTER KIT NEW - 78141013144', 'FUEL FILTER KIT NEW - 78141013144', 1, 8, 451, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(452, 0, 2, 'FUEL FILTER KTM- FUEL PUMP - 61007090100', 'FUEL FILTER KTM- FUEL PUMP - 61007090100', 1, 1, 452, '', 5500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(453, 0, 2, 'FUEL HOSE R9 - 90107018010', 'FUEL HOSE R9 - 90107018010', 1, 1, 453, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(454, 0, 2, 'FUEL INJECTOR ASSY. SET - 76041023044', 'FUEL INJECTOR ASSY. SET - 76041023044', 1, 1, 454, '', 5303.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(455, 0, 2, 'FUEL PUMP - 690 W/FLANGE - 75007088011', 'FUEL PUMP - 690 W/FLANGE - 75007088011', 1, 1, 455, '', 12129.47, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(456, 0, 2, 'GASKET CYLINDER BASE - 77230035000', 'GASKET CYLINDER BASE - 77230035000', 1, 1, 456, '', 321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(457, 0, 2, 'GASKET FUEL PUMP DUKE200 - 90107088002', 'GASKET FUEL PUMP DUKE200 - 90107088002', 1, 1, 457, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(458, 0, 2, 'GASKET MOTO-CYLINDER BASE 990 - 60030035000', 'GASKET MOTO-CYLINDER BASE 990 - 60030035000', 1, 1, 458, '', 964.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(459, 0, 2, 'GASKET MOTO-CYLINDER BASE 990 - 60030135000', 'GASKET MOTO-CYLINDER BASE 990 - 60030135000', 1, 1, 459, '', 910.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(460, 0, 2, 'GASKET SET CPL. 85/105SX 04 - 47030099100', 'GASKET SET CPL. 85/105SX 04 - 47030099100', 1, 1, 460, '', 5049.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(461, 0, 2, 'GASKET WAPU KTM - 78035053000', 'GASKET WAPU KTM - 78035053000', 1, 1, 461, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(462, 0, 2, 'GASKET WATERPUMP COVER - 90135053000', 'GASKET WATERPUMP COVER - 90135053000', 1, 1, 462, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(463, 0, 2, 'GEARS WATERPUMP ROTOR - 90135055000', 'GEARS WATERPUMP ROTOR - 90135055000', 1, 1, 463, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(464, 0, 2, 'GPS BRACKET UNIVERSAL 1190 - 76012992044', 'GPS BRACKET UNIVERSAL 1190 - 76012992044', 1, 1, 464, '', 4928.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(465, 0, 2, 'GR. BALL BEARING. 6003-2RSH/C3HMTF - 0625060037', 'GR. BALL BEARING. 6003-2RSH/C3HMTF - 0625060037', 1, 1, 465, '', 910.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(466, 0, 2, 'GR. BALL BEARING. 6203-2RSH/C3HMTF - 0625062032', 'GR. BALL BEARING. 6203-2RSH/C3HMTF - 0625062032', 1, 1, 466, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(467, 0, 2, 'GRIP SET OPEN END - 76002021000', 'GRIP SET OPEN END - 76002021000', 1, 1, 467, '', 986.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(468, 0, 2, 'GRIPS - THROTTLE GRIPS CPL - 90102010000', 'GRIPS - THROTTLE GRIPS CPL - 90102010000', 1, 1, 468, '', 321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(469, 0, 2, 'GRIPS 2K - SET - 63002021100', 'GRIPS 2K - SET - 63002021100', 1, 1, 469, '', 1000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(471, 0, 2, 'HANDGUARD BLACK/ORANGE - 7810297905004', 'HANDGUARD BLACK/ORANGE - 7810297905004', 1, 1, 471, '', 2250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(472, 0, 2, 'HANDGUARD MOUNTING KIT - ORANGE - 77702979044', 'HANDGUARD MOUNTING KIT - ORANGE - 77702979044', 1, 1, 472, '', 522.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(473, 0, 2, 'HANDLE BAR CLAMP BIKERS KTM8', 'HANDLE BAR CLAMP BIKERS KTM8', 1, 1, 473, '', 3050.40, 4920.00, 0, '2015-07-31', 0, 4920.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(474, 0, 2, 'HANDLEBAR - DUKE 200 - 90102001000', 'HANDLEBAR - DUKE 200 - 90102001000', 1, 1, 474, '', 3000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(475, 0, 2, 'HEAT PROTECTOR 1190 - 60307040080', 'HEAT PROTECTOR 1190 - 60307040080', 1, 1, 475, '', 1856.92, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(476, 0, 2, 'HOLE SHOT KTM FACTORY START 250-350 - SXS11540100', 'HOLE SHOT KTM FACTORY START 250-350 - SXS11540100', 1, 1, 476, '', 3857.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(477, 0, 2, 'HOSE KTM FUEL DUKE200 - 90107018020', 'HOSE KTM FUEL DUKE200 - 90107018020', 1, 1, 477, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(478, 0, 2, 'IGNITION COIL KTM - 58439006000', 'IGNITION COIL KTM - 58439006000', 1, 1, 478, '', 2678.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(479, 0, 2, 'KEY - BLANK KEY DUKE200 - 90111067100', 'KEY - BLANK KEY DUKE200 - 90111067100', 1, 1, 479, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(480, 0, 2, 'KICK START SHAFT - 45233050044', 'KICK START SHAFT - 45233050044', 1, 1, 480, '', 2410.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(481, 0, 2, 'KICK STARTER CPL - 77033170044 - 250 SX-F', 'KICK STARTER CPL - 77033170044 - 250 SX-F', 1, 1, 481, '', 3191.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(482, 0, 2, 'KICKSTARTER SPRING - 45233054000', 'KICKSTARTER SPRING - 45233054000', 1, 1, 482, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(483, 0, 2, 'KTM IXIL L3X DUAL EXHAUST PIPE - DUKE 200', 'KTM IXIL L3X DUAL EXHAUST PIPE - DUKE 200', 1, 1, 483, '', 0.00, 23145.00, 0, '2015-07-31', 0, 23145.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(485, 0, 2, 'BLANK KEY DUKE200 - 90111067100', 'BLANK KEY DUKE200 - 90111067100', 1, 1, 485, '', 267.86, 550.00, 2, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(486, 0, 2, 'KTM OIL SCRAPER RING - 58030631000', 'KTM OIL SCRAPER RING - 58030631000', 1, 1, 486, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(487, 0, 2, 'KTM SPARKPLUG-NGK-CR9EKB -250/450 SX-F-77039093000', 'KTM SPARKPLUG-NGK-CR9EKB -250/450 SX-F-77039093000', 1, 1, 487, '', 580.36, 1100.00, 0, '2015-07-31', 0, 1100.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(488, 0, 2, 'LAMBDA SENSOR - 350 FREERIDE - 75041090000', 'LAMBDA SENSOR - 350 FREERIDE - 75041090000', 1, 1, 488, '', 4392.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(490, 0, 2, 'LEVER BRAKE - 50SX - 45113002000', 'LEVER BRAKE - 50SX - 45113002000', 1, 1, 490, '', 1660.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(491, 0, 2, 'LEVER BRAKE - 60013002000', 'LEVER BRAKE - 60013002000', 1, 1, 491, '', 2862.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(492, 0, 2, 'LEVER BRAKE LOOSE 85SX - 47013002000', 'LEVER BRAKE LOOSE 85SX - 47013002000', 1, 1, 492, '', 1607.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(493, 0, 2, 'LEVER CLUTCH - 61002031000', 'LEVER CLUTCH - 61002031000', 1, 1, 493, '', 2305.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(494, 0, 2, 'LEVER CLUTCH - BREMBO - 54802031000', 'LEVER CLUTCH - BREMBO - 54802031000', 1, 1, 494, '', 1645.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(495, 0, 2, 'LEVER CLUTCH 450 SX-F - 50302031300', 'LEVER CLUTCH 450 SX-F - 50302031300', 1, 1, 495, '', 1767.86, 3630.00, 0, '2015-07-31', 0, 3630.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(496, 0, 2, 'LEVER CLUTCH 65SX SHORT - 54602031000', 'LEVER CLUTCH 65SX SHORT - 54602031000', 1, 1, 496, '', 1607.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(497, 0, 2, 'LEVER CLUTCH CPL - DUKE200 - 90102031000', 'LEVER CLUTCH CPL - DUKE200 - 90102031000', 1, 1, 497, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(498, 0, 2, 'LEVER CLUTCH-990 - 61002031100', 'LEVER CLUTCH-990 - 61002031100', 1, 1, 498, '', 2410.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(499, 0, 2, 'KTM BRAKE AND SHIFT LEVER ORANGE - D200/390', 'KTM BRAKE AND SHIFT LEVER ORANGE - D200/390', 1, 1, 499, '', 1251.79, 4110.00, 0, '2015-07-31', 0, 4110.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(500, 0, 2, 'LEVER HANDBRAKE+SPRING/250SX-F - 54813002200', 'LEVER HANDBRAKE+SPRING/250SX-F - 54813002200', 1, 1, 500, '', 1251.79, 2400.00, 1, '2015-07-31', 0, 2400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(501, 0, 2, 'LEVER HANDBRAKE CPL-690 - 62513002044', 'LEVER HANDBRAKE CPL-690 - 62513002044', 1, 1, 501, '', 3803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(502, 0, 2, 'LEVER HANDBRAKE CPL-SMT - 58713002100', 'LEVER HANDBRAKE CPL-SMT - 58713002100', 1, 1, 502, '', 3214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(503, 0, 2, 'LEVER HANDBRAKE DUKE200 - 90113002000', 'LEVER HANDBRAKE DUKE200 - 90113002000', 1, 1, 503, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(504, 0, 2, 'LEVER KTM/SHIFT 250 - 54834031000', 'LEVER KTM/SHIFT 250 - 54834031000', 1, 1, 504, '', 2496.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(505, 0, 2, 'LEVER SET ADJUSTABLE BIKERS KTM3 / KTM4', 'LEVER SET ADJUSTABLE BIKERS KTM3 / KTM4', 1, 1, 505, '', 4141.60, 6680.00, 0, '2015-07-31', 0, 6680.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(506, 0, 2, 'LEVER SHIFT CPL - 2 STROKE - 54734031000', 'LEVER SHIFT CPL - 2 STROKE - 54734031000', 1, 1, 506, '', 2196.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(507, 0, 2, 'LEVER SHIFT - KTM DUKE 390 ', 'LEVER SHIFT - KTM DUKE 390 ', 1, 1, 507, '', 0.00, 2100.00, 0, '2015-07-31', 0, 2100.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(508, 0, 2, 'LEVER SHIFT CPL DUKE200 - 90134031033', 'LEVER SHIFT CPL DUKE200 - 90134031033', 1, 1, 508, '', 964.29, 1980.00, 0, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(509, 0, 2, 'LINING DISK KIT - 46032011044', 'LINING DISK KIT - 46032011044', 1, 1, 509, '', 3000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(510, 0, 2, 'LOCK CYL.F.CASES - 60312924050', 'LOCK CYL.F.CASES - 60312924050', 1, 1, 510, '', 1571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(511, 0, 2, 'MASTER CYLINDER - 46102030100', 'MASTER CYLINDER - 46102030100', 1, 1, 511, '', 8785.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(512, 0, 2, 'MIRROR DUKE200 L/S - 90112040000', 'MIRROR DUKE200 L/S - 90112040000', 1, 1, 512, '', 910.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(513, 0, 2, 'MIRROR DUKE200 R/S - 90112041000', 'MIRROR DUKE200 R/S - 90112041000', 1, 1, 513, '', 910.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(514, 0, 2, 'MIRROR KTM - 6031204000', 'MIRROR KTM - 6031204000', 1, 1, 514, '', 2785.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(515, 0, 2, 'MIRROR KTM - 990 S.MOTO REAR LEFT - 61112040000', 'MIRROR KTM - 990 S.MOTO REAR LEFT - 61112040000', 1, 1, 515, '', 1017.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(516, 0, 2, 'MIRROR KTM - 990 S.MOTO REAR RIGHT - 61112041000', 'MIRROR KTM - 990 S.MOTO REAR RIGHT - 61112041000', 1, 1, 516, '', 1017.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(517, 0, 2, 'NEEDLE BEARING KBK 14x18x17 03 - 47030034000', 'NEEDLE BEARING KBK 14x18x17 03 - 47030034000', 1, 1, 517, '', 1339.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(518, 0, 2, 'NEEDLE VALVE CPL. 2.5 - 46231020100', 'NEEDLE VALVE CPL. 2.5 - 46231020100', 1, 1, 518, '', 1767.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(519, 0, 2, 'NUT SCREW AXLE M8 - 90109082000', 'NUT SCREW AXLE M8 - 90109082000', 1, 1, 519, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(520, 0, 2, 'NUT-DOME WAPU WHEEL DUKE200 - 90135058000', 'NUT-DOME WAPU WHEEL DUKE200 - 90135058000', 1, 1, 520, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(521, 0, 2, 'OFFROAD DANGLE 1190 - 60312953000', 'OFFROAD DANGLE 1190 - 60312953000', 1, 1, 521, '', 3812.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(522, 0, 2, 'OIL FILTER - 505/530 - 77338005100', 'OIL FILTER - 505/530 - 77338005100', 1, 1, 522, '', 313.01, 700.00, 3, '2015-07-31', 0, 700.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(523, 0, 2, 'OIL FILTER - 690 - END SMC LONG - 58038005100', 'OIL FILTER - 690 - END SMC LONG - 58038005100', 1, 1, 523, '', 375.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(525, 0, 2, 'OIL FILTER DUKE 200/390 - 90138015000', 'OIL FILTER DUKE 200/390 - 90138015000', 1, 1, 525, '', 321.43, 660.00, 1, '2015-07-31', 0, 660.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(526, 0, 2, 'OIL FILTER -OIL SCREEN - 59038016000', 'OIL FILTER -OIL SCREEN - 59038016000', 1, 1, 526, '', 400.89, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(527, 0, 2, 'OIL FILTER SHORT W/GASKET - 59038046144', 'OIL FILTER SHORT W/GASKET - 59038046144', 1, 1, 527, '', 263.37, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(528, 0, 2, 'OIL FILTER WITH GASKET- 77038005044 - 250/450/500', 'OIL FILTER WITH GASKET- 77038005044 - 250/450/500', 1, 1, 528, '', 271.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(529, 0, 2, 'OIL INFILLING HOSE - 60307026100', 'OIL INFILLING HOSE - 60307026100', 1, 1, 529, '', 562.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(530, 0, 2, 'OIL SEAL DUST CAP - 43x53,4x5 - 43570624', 'OIL SEAL DUST CAP - 43x53,4x5 - 43570624', 1, 1, 530, '', 535.71, 1100.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, ' 43570624', '', 'NDC-TMP', 4),
	(531, 0, 2, 'OIL SEAL RING - 48600347', 'OIL SEAL RING - 48600347', 1, 1, 531, '', 776.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(532, 0, 2, 'OIL SEAL RING - FORK 85SX- 43570201', 'OIL SEAL RING - FORK 85SX- 43570201', 1, 1, 532, '', 696.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(533, 0, 2, 'OIL SEAL RING 15X24X5 - 45133031000', 'OIL SEAL RING 15X24X5 - 45133031000', 1, 1, 533, '', 160.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(534, 0, 2, 'OIL SEAL RING 15X24X7- 45130076000', 'OIL SEAL RING 15X24X7- 45130076000', 1, 1, 534, '', 642.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(535, 0, 2, 'OIL SHAFT SEAL RING - 0760324571 - 250 SX-f', 'OIL SHAFT SEAL RING - 0760324571 - 250 SX-f', 1, 1, 535, '', 114.80, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(536, 0, 2, 'OIL TANK BRAKE FLUID RESERVOIR - 90113930144', 'OIL TANK BRAKE FLUID RESERVOIR - 90113930144', 1, 1, 536, '', 1687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(537, 0, 2, 'OIL FILTER - DUKE 200/390 *021623', 'OIL FILTER - DUKE 200/390 *021623', 1, 1, 537, '', 295.00, 660.00, 28, '2015-07-31', 0, 660.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(538, 0, 2, 'O-RING 50 SX - 0770022020', 'O-RING 50 SX - 0770022020', 1, 1, 538, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(539, 0, 2, 'O-RING VITON 29,87X1,78 - 0770298178', 'O-RING VITON 29,87X1,78 - 0770298178', 1, 1, 539, '', 71.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(540, 0, 2, 'PAIR OF WASHER M8 - 60303022035', 'PAIR OF WASHER M8 - 60303022035', 1, 1, 540, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(541, 0, 2, 'PISTON KIT 50 SX  - 45230007000 I', 'PISTON KIT 50 SX  - 45230007000 I', 1, 1, 541, '', 4062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(542, 0, 2, 'PISTON KIT CPL. 90630007000', 'PISTON KIT CPL. 90630007000', 1, 8, 542, '', 3589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(543, 0, 2, 'PISTON KIT RING - 75330031044 DUKE R', 'PISTON KIT RING - 75330031044 DUKE R', 1, 1, 543, '', 2031.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(544, 0, 2, 'PISTON KIT RING - 75330031144', 'PISTON KIT RING - 75330031144', 1, 1, 544, '', 2031.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(545, 0, 2, 'PISTON RING - 45230030000 - 50 SX', 'PISTON RING - 45230030000 - 50 SX', 1, 1, 545, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(546, 0, 2, 'PISTON RING - 77030030200', 'PISTON RING - 77030030200', 1, 1, 546, '', 1232.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(547, 0, 2, 'PISTON RING - 77230030000', 'PISTON RING - 77230030000', 1, 1, 547, '', 1232.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(548, 0, 2, 'PISTON RING - 78030030100', 'PISTON RING - 78030030100', 1, 1, 548, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(549, 0, 2, 'PISTON RING - 85SX - 47030030000', 'PISTON RING - 85SX - 47030030000', 1, 1, 549, '', 1821.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(550, 0, 2, 'PISTON RING - 90630030010 - DUKE 200', 'PISTON RING - 90630030010 - DUKE 200', 1, 1, 550, '', 535.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(551, 0, 2, 'PISTON RING 45MM-65CCM - 46030030500', 'PISTON RING 45MM-65CCM - 46030030500', 1, 1, 551, '', 1821.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(552, 0, 2, 'PISTON RING D=101-H1.25 - 61030030000', 'PISTON RING D=101-H1.25 - 61030030000', 1, 1, 552, '', 1285.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(553, 0, 2, 'PISTON RING D=97 COMPRESSION - 77330030100', 'PISTON RING D=97 COMPRESSION - 77330030100', 1, 1, 553, '', 1017.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(554, 0, 2, 'PISTON ROD REP.SET 50SX - 45230015000', 'PISTON ROD REP.SET 50SX - 45230015000', 1, 1, 554, '', 7125.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(555, 0, 2, 'PLATE 690END/SMC-ALUMINUM-SKID - 76503090100', 'PLATE 690END/SMC-ALUMINUM-SKID - 76503090100', 1, 1, 555, '', 6714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(556, 0, 2, 'PRESSURE REGULATOR CPL. - 75007088012', 'PRESSURE REGULATOR CPL. - 75007088012', 1, 1, 556, '', 8830.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(557, 0, 2, 'RADIATOR CAP - SMALL - ADVEN950 - 58035016000', 'RADIATOR CAP - SMALL - ADVEN950 - 58035016000', 1, 1, 557, '', 848.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(558, 0, 2, 'RADIATOR COVER BAR 1.4 - 62535009000', 'RADIATOR COVER BAR 1.4 - 62535009000', 1, 1, 558, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(559, 0, 2, 'RC8 1190 - BRAKEPAD KTM - FRONT - 69013030000', 'RC8 1190 - BRAKEPAD KTM - FRONT - 69013030000', 1, 1, 559, '', 2687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(560, 0, 2, 'RC8 1190 - BRAKEPAD KTM - REAR - 69013090000', 'RC8 1190 - BRAKEPAD KTM - REAR - 69013090000', 1, 1, 560, '', 1272.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(561, 0, 2, 'REAR BRAKE FLUID RESERVOIR CAP BIKERS KTM11', 'REAR BRAKE FLUID RESERVOIR CAP BIKERS KTM11', 1, 1, 561, '', 1302.00, 2100.00, 0, '2015-07-31', 0, 2100.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(562, 0, 2, 'REAR DISC BRAKE CALIPER COVER BIKERS KTM14', 'REAR DISC BRAKE CALIPER COVER BIKERS KTM14', 1, 1, 562, '', 1841.40, 2970.00, 0, '2015-07-31', 0, 2970.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(563, 0, 2, 'REAR FOOTREST KTM23', 'REAR FOOTREST KTM23', 1, 1, 563, '', 0.00, 14810.00, 0, '2015-07-31', 0, 14810.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(564, 0, 2, 'REAR SET GEAR SHIFT AND FOOTBRAKE', 'REAR SET GEAR SHIFT AND FOOTBRAKE', 1, 9, 564, '', 0.00, 30900.00, 1, '2015-07-31', 0, 30900.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(565, 0, 2, 'REAR SPROCKET 48-T - 46010051048', 'REAR SPROCKET 48-T - 46010051048', 1, 1, 565, '', 2147.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(566, 0, 2, 'REAR WHEEL SLIDER ', 'REAR WHEEL SLIDER ', 1, 1, 566, '', 0.00, 5195.00, 0, '2015-07-31', 0, 5195.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(567, 0, 2, 'REAR WHEEL CPL - 90110001044', 'REAR WHEEL CPL - 90110001044', 1, 1, 567, '', 10125.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(568, 0, 2, 'REED VALVE MEMBRANE CASE - 46230051044', 'REED VALVE MEMBRANE CASE - 46230051044', 1, 1, 568, '', 5745.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(569, 0, 2, 'REGULATOR VOLTAGE - 60011034100', 'REGULATOR VOLTAGE - 60011034100', 1, 1, 569, '', 3910.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(570, 0, 2, 'REGULATOR VOLTAGE - 80011034000', 'REGULATOR VOLTAGE - 80011034000', 1, 1, 570, '', 2274.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(571, 0, 2, 'REGULATOR VOLTAGE 350SX-F - 77211034000', 'REGULATOR VOLTAGE 350SX-F - 77211034000', 1, 1, 571, '', 5100.90, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(572, 0, 2, 'REGULATOR VOLTAGE DUKE200 - 90111034000', 'REGULATOR VOLTAGE DUKE200 - 90111034000', 1, 1, 572, '', 3053.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(573, 0, 2, 'RELAY STARTER 950 ADVENTURE - 60011058000', 'RELAY STARTER 950 ADVENTURE - 60011058000', 1, 1, 573, '', 2447.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(574, 0, 2, 'RELAY FLASHER UNIT HELLA - 44611207100', 'RELAY FLASHER UNIT HELLA - 44611207100', 1, 1, 574, '', 2108.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(575, 0, 2, 'RELAY STARTER - 58211058000', 'RELAY STARTER - 58211058000', 1, 1, 575, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(576, 0, 2, 'RELAY STARTER - 90111058000', 'RELAY STARTER - 90111058000', 1, 1, 576, '', 857.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(577, 0, 2, 'REPAIR KIT - 78141013344', 'REPAIR KIT - 78141013344', 1, 1, 577, '', 2025.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(578, 0, 2, 'REPAIR KIT - 78141013444', 'REPAIR KIT - 78141013444', 1, 1, 578, '', 1888.10, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(579, 0, 2, 'REPAIR KIT - 78141013544', 'REPAIR KIT - 78141013544', 1, 1, 579, '', 1031.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(580, 0, 2, 'REPAIR KIT 50 SX- 65 SX - R703', 'REPAIR KIT 50 SX- 65 SX - R703', 1, 1, 580, '', 2437.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(581, 0, 2, 'REPAIR KIT BEARING/SEAL UP 07 - R12012', 'REPAIR KIT BEARING/SEAL UP 07 - R12012', 1, 1, 581, '', 2263.40, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(582, 0, 2, 'REPAIR KIT BRAKE PISTON-50SX - 45113019100', 'REPAIR KIT BRAKE PISTON-50SX - 45113019100', 1, 8, 582, '', 375.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(583, 0, 2, 'REPAIR KIT- FORK CPL - D200 90101000010', 'REPAIR KIT- FORK CPL - D200 90101000010', 1, 1, 583, '', 1683.04, 6010.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '90101000010', '', 'NDC-TMP', 4),
	(584, 0, 2, 'REPAIR KIT PISTON HANDBRAKE FRONT - 85SX 47013008000', 'REPAIR KIT PISTON HANDBRAKE FRONT - 85SX 47013008000', 1, 1, 584, '', 1017.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(585, 0, 2, 'REPAIR KIT SHIMS - R15017', 'REPAIR KIT SHIMS - R15017', 1, 1, 585, '', 2089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(586, 0, 2, 'REPAIR KIT STEERING DAMPER - R14038', 'REPAIR KIT STEERING DAMPER - R14038', 1, 1, 586, '', 468.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(587, 0, 2, 'REPAIR SET PISTON 9.5MM - 47002032000', 'REPAIR SET PISTON 9.5MM - 47002032000', 1, 1, 587, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(588, 0, 2, 'RETAINING SPRING 65SX - 46213018000', 'RETAINING SPRING 65SX - 46213018000', 1, 1, 588, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(589, 0, 2, 'ROTOR FLYWHEEL 50SX - 45139005100', 'ROTOR FLYWHEEL 50SX - 45139005100', 1, 1, 589, '', 1875.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(590, 0, 2, 'RUBBER - KTM DUKE200 - 90134035000', 'RUBBER - KTM DUKE200 - 90134035000', 1, 1, 590, '', 107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(591, 0, 2, 'RUBBER FOAM TANK CAP - 76507008060', 'RUBBER FOAM TANK CAP - 76507008060', 1, 1, 591, '', 192.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(592, 0, 2, 'S.DUKE REAR WHEEL BEARING 990 - 0625062052', 'S.DUKE REAR WHEEL BEARING 990 - 0625062052', 1, 1, 592, '', 1017.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(593, 0, 2, 'SCREW COUNTER SUNK SCREW-ISA45 - 0019080206S', 'SCREW COUNTER SUNK SCREW-ISA45 - 0019080206S', 1, 1, 593, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(594, 0, 2, 'SCREW FOR FILTER SET - 61007091000', 'SCREW FOR FILTER SET - 61007091000', 1, 1, 594, '', 160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(595, 0, 2, 'SCREW HH COLLAR M6X16 SW10 - J025060163', 'SCREW HH COLLAR M6X16 SW10 - J025060163', 1, 1, 595, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(596, 0, 2, 'SCREW HH COLLAR M8X30 - DUKE200 - J025080303S', 'SCREW HH COLLAR M8X30 - DUKE200 - J025080303S', 1, 1, 596, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(597, 0, 2, 'SCREW + WASHER KTM - 59033034044', 'SCREW + WASHER KTM - 59033034044', 1, 1, 597, '', 174.11, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(598, 0, 2, 'SCREW M8X30-HH COLLAR - 90134034100', 'SCREW M8X30-HH COLLAR - 90134034100', 1, 1, 598, '', 107.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(599, 0, 2, 'SCREW/ BANJO SCREW - 90113013000', 'SCREW/ BANJO SCREW - 90113013000', 1, 1, 599, '', 107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(600, 0, 2, 'SCREW/BLEEDER SCREW - 90113121000', 'SCREW/BLEEDER SCREW - 90113121000', 1, 1, 600, '', 53.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(601, 0, 2, 'SELF LOCKING NUT M8 CU - 51010086100', 'SELF LOCKING NUT M8 CU - 51010086100', 1, 1, 601, '', 107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(602, 0, 2, 'SENSOR ADV. GAS LEVEL - 58207080100', 'SENSOR ADV. GAS LEVEL - 58207080100', 1, 1, 602, '', 1647.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(603, 0, 2, 'SHAFT SEAL RING - 0760223270', 'SHAFT SEAL RING - 0760223270', 1, 1, 603, '', 321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(604, 0, 2, 'SHAFT SEAL RING - 0760263561 - 50SX', 'SHAFT SEAL RING - 0760263561 - 50SX', 1, 1, 604, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(605, 0, 2, 'SHAFT SEAL RING - 12X24X5 - J760122455', 'SHAFT SEAL RING - 12X24X5 - J760122455', 1, 1, 605, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(606, 0, 2, 'SHAFT SEAL RING - 14X24X6 - 0760142460', 'SHAFT SEAL RING - 14X24X6 - 0760142460', 1, 1, 606, '', 321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(607, 0, 2, 'SHAFT SEAL RING - 46035056100', 'SHAFT SEAL RING - 46035056100', 1, 1, 607, '', 375.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(608, 0, 2, 'SHAFT SEAL RING 22X35X8 - J760223508', 'SHAFT SEAL RING 22X35X8 - J760223508', 1, 1, 608, '', 107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(609, 0, 2, 'SHAFT SEAL RING 26X42X8 - J760264208', 'SHAFT SEAL RING 26X42X8 - J760264208', 1, 1, 609, '', 107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(610, 0, 2, 'SHAFT SEAL RING KTM - 0760102455', 'SHAFT SEAL RING KTM - 0760102455', 1, 1, 610, '', 375.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(611, 0, 2, 'SHAFT SEAL RING VITON - 0760405560', 'SHAFT SEAL RING VITON - 0760405560', 1, 1, 611, '', 321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(612, 0, 2, 'SIDE STAND SPRING L=116 MM - 61003024000', 'SIDE STAND SPRING L=116 MM - 61003024000', 1, 1, 612, '', 348.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(613, 0, 2, 'SIDEBAGS - 990 SMT - 62012025100', 'SIDEBAGS - 990 SMT - 62012025100', 1, 9, 613, '', 16071.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(614, 0, 2, 'SIDE COVER R/S REAR', 'SIDE COVER R/S REAR', 1, 9, 614, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(615, 0, 2, 'SIGNAL LIGHT FLASHER CPL FRONT-L/S DUKE200 - 90114126000', 'SIGNAL LIGHT FLASHER CPL FRONT-L/S DUKE200 - 90114126000', 1, 1, 615, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(616, 0, 2, 'SIGNAL LIGHT FLASHER CPL REAR-L/S DUKE200 - 90114026000', 'SIGNAL LIGHT FLASHER CPL REAR-L/S DUKE200 - 90114026000', 1, 1, 616, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(617, 0, 2, 'SIGNAL LIGHT FRONT LS-REAR-RS - 54814025200', 'SIGNAL LIGHT FRONT LS-REAR-RS - 54814025200', 1, 1, 617, '', 1414.29, 2905.00, 0, '2015-07-31', 0, 2905.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(618, 0, 2, 'SIGNAL LIGHT FRONT RS-REAR LS - 54814026200', 'SIGNAL LIGHT FRONT RS-REAR LS - 54814026200', 1, 1, 618, '', 1414.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(620, 0, 2, 'SIGNAL LIGHT LH-FRONT-RH REAR - 54814025100', 'SIGNAL LIGHT LH-FRONT-RH REAR - 54814025100', 1, 1, 620, '', 1414.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(621, 0, 2, 'SIGNAL LIGHT-FRONT L/S REAR R/S - 60114025000', 'SIGNAL LIGHT-FRONT L/S REAR R/S - 60114025000', 1, 1, 621, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(622, 0, 2, 'SILENCER SET TITANIUM LS+RS 05 - 62505099000', 'SILENCER SET TITANIUM LS+RS 05 - 62505099000', 1, 1, 622, '', 46285.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(623, 0, 2, 'SILENCER R/S 08', 'SILENCER R/S 08', 1, 1, 623, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(624, 0, 2, 'SKIDPLATE ALU. 1190 60303990044', 'SKIDPLATE ALU. 1190 60303990044', 1, 1, 624, '', 11250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(625, 0, 2, 'SMT HANDGUARD CPL. LS + RS BLACK - 6200207904430', 'SMT HANDGUARD CPL. LS + RS BLACK - 6200207904430', 1, 1, 625, '', 3321.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(626, 0, 2, 'SMT THROTTLE CABLE CLOSE - 62502092100', 'SMT THROTTLE CABLE CLOSE - 62502092100', 1, 1, 626, '', 1553.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(627, 0, 2, 'SPACER BUSH. 8,5x15x7,5 05 - 61005009000', 'SPACER BUSH. 8,5x15x7,5 05 - 61005009000', 1, 1, 627, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(628, 0, 2, 'SPACER BUSHING KRT INSIDE - 90110054000 ', 'SPACER BUSHING KRT INSIDE - 90110054000 ', 1, 1, 628, '', 267.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(629, 0, 2, 'SPACER BUSHING REAR WHEEL R/S - 90110013000', 'SPACER BUSHING REAR WHEEL R/S - 90110013000', 1, 1, 629, '', 214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(630, 0, 2, 'SPARKPLUG CONNECT CPL. 90139090033', 'SPARKPLUG CONNECT CPL. 90139090033', 1, 1, 630, '', 857.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(631, 0, 2, 'SPARKPLUG INSERT SHAFT - 61236075000', 'SPARKPLUG INSERT SHAFT - 61236075000', 1, 1, 631, '', 589.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(632, 0, 2, 'SPARKPLUG KTM - LKAR8A-9', 'SPARKPLUG KTM - LKAR8A-9', 1, 1, 632, '', 714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(633, 0, 2, 'SIDE STAND BASE KTM DUKE 200/390 - 021616', 'SIDE STAND BASE KTM DUKE 200/390 - 021616', 1, 1, 633, '', 730.00, 1265.00, 1, '2015-07-31', 0, 1265.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(634, 0, 2, 'SPARKPLUG KTM- 350 SX-F - 77239093000-LMAR9AI-8', 'SPARKPLUG KTM- 350 SX-F - 77239093000-LMAR9AI-8', 1, 1, 634, '', 580.36, 990.00, 2, '2015-07-31', 0, 990.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(635, 0, 2, 'SPARKPLUG KTM- 65/50 SX - 45239093000 - LR8B', 'SPARKPLUG KTM- 65/50 SX - 45239093000 - LR8B', 1, 1, 635, '', 468.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(636, 0, 2, 'SPARKPLUG KR8DI - 61139093000', 'SPARKPLUG KR8DI - 61139093000', 1, 1, 636, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(637, 0, 2, 'SPARKPLUG KTM DUKE 200/690 NGK LKAR8819 (60139093000)', 'SPARKPLUG KTM DUKE 200/690 NGK LKAR8819 (60139093000)', 1, 1, 637, '', 1004.46, 1735.00, 0, '2015-07-31', 0, 1735.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(638, 0, 2, 'SPARKPLUG NGK BR8ECM - 54331093410', 'SPARKPLUG NGK BR8ECM - 54331093410', 1, 1, 638, '', 482.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(639, 0, 2, 'SPARKPLUG NGK LMAR7A-9 690 DUKE 13 - 69139093000', 'SPARKPLUG NGK LMAR7A-9 690 DUKE 13 - 69139093000', 1, 1, 639, '', 1044.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(640, 0, 2, 'SPARKPLUG RC8 LKAR9B19 - 61239093200', 'SPARKPLUG RC8 LKAR9B19 - 61239093200', 1, 1, 640, '', 1071.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(641, 0, 2, 'SPECIAL WASHER 8X24 ALU H=2,6', 'SPECIAL WASHER 8X24 ALU H=2,6', 1, 1, 641, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(642, 0, 2, 'SPLASH PROTECT 05', 'SPLASH PROTECT 05', 1, 1, 642, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(643, 0, 2, 'SPOILER DUKE BLACK MASK L/S - 90108002000', 'SPOILER DUKE BLACK MASK L/S - 90108002000', 1, 1, 643, '', 1250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(644, 0, 2, 'SPOILER DUKE BLACK MASK R/S - 90108002000', 'SPOILER DUKE BLACK MASK R/S - 90108002000', 1, 1, 644, '', 1250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(645, 0, 2, 'SPROCKET 14T DUKE200 - 90133029014', 'SPROCKET 14T DUKE200 - 90133029014', 1, 1, 645, '', 482.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(646, 0, 2, 'SPROCKET ALU 45 T. KTM 9011095104504', 'SPROCKET ALU 45 T. KTM 9011095104504', 1, 1, 646, '', 2386.61, 3740.00, 4, '2015-07-31', 0, 3740.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(647, 0, 2, 'SPROCKET FRONT 15T - 50033029015', 'SPROCKET FRONT 15T - 50033029015', 1, 1, 647, '', 562.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(648, 0, 2, 'SPROCKET KTM ENGINE 38T REAR - 58310051038', 'SPROCKET KTM ENGINE 38T REAR - 58310051038', 1, 1, 648, '', 2025.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(649, 0, 2, 'SPROCKET REAR  48T ORANGE - 5901005104804', 'SPROCKET REAR  48T ORANGE - 5901005104804', 1, 1, 649, '', 2428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(650, 0, 2, 'STATOR 50 SX FLYWHEEL - 45139004000', 'STATOR 50 SX FLYWHEEL - 45139004000', 1, 1, 650, '', 4446.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(651, 0, 2, 'STEERING BOLT BIKERS KTM7', 'STEERING BOLT BIKERS KTM7', 1, 1, 651, '', 843.20, 1360.00, 0, '2015-07-31', 0, 1360.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(652, 0, 2, 'STICKER CHROME GRAPHIC KIT - 90108999100', 'STICKER CHROME GRAPHIC KIT - 90108999100', 1, 1, 652, '', 2428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(653, 0, 2, 'STICKER DUKE TANK PROTECTION - 90107914000', 'STICKER DUKE TANK PROTECTION - 90107914000', 1, 1, 653, '', 1406.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(654, 0, 2, 'STICKER RIM 690 SET - 76009999000', 'STICKER RIM 690 SET - 76009999000', 1, 9, 654, '', 1312.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(655, 0, 2, 'STICKER RIM ORANGE - 61109099000', 'STICKER RIM ORANGE - 61109099000', 1, 1, 655, '', 867.86, 2310.00, 3, '2015-07-31', 0, 2310.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(697, 0, 27, 'VESPA OIL FILTER - 203.3012', 'VESPA OIL FILTER - 203.3012', 1, 1, 697, '', 0.00, 865.00, 2, '2015-07-31', 0, 865.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(698, 0, 27, 'VESPA OIL FILTER - MALOSSI  RED CHILLI - 313382', 'VESPA OIL FILTER - MALOSSI  RED CHILLI - 313382', 1, 1, 698, '', 0.00, 2035.00, 0, '2015-07-31', 0, 2035.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(699, 0, 27, 'LML OIL FILTER ', 'LML OIL FILTER ', 1, 1, 699, '', 0.00, 1345.00, 0, '2015-07-31', 0, 1345.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(725, 0, 25, 'MOTORSIKLO MAGAZINE ', 'MOTORSIKLO MAGAZINE ', 1, 1, 725, '', 0.00, 180.00, 7, '2015-07-31', 0, 180.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(726, 0, 25, 'O-RING DUKE 200/390 - 129 N', 'O-RING DUKE 200/390 - 129 N', 1, 1, 726, '', 15.00, 55.00, 18, '2015-07-31', 0, 55.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(727, 0, 25, 'O-RING KTM 350/450 SX-F', 'O-RING KTM 350/450 SX-F', 1, 1, 727, '', 15.00, 110.00, 8, '2015-07-31', 0, 110.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(728, 0, 25, 'MONSTER FRONT INDICATOR YELLOW - 021012', 'MONSTER FRONT INDICATOR YELLOW - 021012', 1, 1, 728, '', 285.00, 385.00, 1, '2015-07-31', 0, 385.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(729, 0, 25, 'ACERBIS MX3 GLOVES LARGE - GIALLO YELLOW ', 'ACERBIS MX3 GLOVES LARGE - GIALLO YELLOW ', 1, 1, 729, '', 900.00, 1650.00, 1, '2015-07-31', 0, 1650.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(730, 0, 40, 'ACERBIS MX3 GLOVES LARGE - VERDE GREEN ', 'ACERBIS MX3 GLOVES LARGE - VERDE GREEN ', 2, 1, 730, '', 900.00, 1650.00, 1, '2015-07-31', 0, 1650.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(731, 0, 25, 'BIKE RALLY T-SHIRT WHITE (M) ', 'BIKE RALLY T-SHIRT WHITE (M) ', 1, 1, 731, '', 130.90, 330.00, 1, '2015-07-31', 0, 330.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(732, 0, 25, 'BIKE RALLY T-SHIRT WHITE (L) ', 'BIKE RALLY T-SHIRT WHITE (L) ', 1, 1, 732, '', 130.90, 330.00, 46, '2015-07-31', 0, 330.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(733, 0, 25, 'BIKE RALLY T-SHIRT WHITE (XL) ', 'BIKE RALLY T-SHIRT WHITE (XL) ', 1, 1, 733, '', 130.90, 330.00, 15, '2015-07-31', 0, 330.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(734, 0, 25, 'BIKE RALLY T-SHIRT WHITE (2XL) ', 'BIKE RALLY T-SHIRT WHITE (2XL) ', 1, 1, 734, '', 140.90, 330.00, 14, '2015-07-31', 0, 330.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(735, 0, 25, 'MATTE CHROME INTAKE COVER KIT ', 'MATTE CHROME INTAKE COVER KIT ', 1, 1, 735, '', 0.00, 5500.00, 0, '2015-07-31', 0, 5500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(736, 0, 25, 'STAR BOLT NAKED INTAKE KIT 1010-1459', 'STAR BOLT NAKED INTAKE KIT 1010-1459', 1, 1, 736, '', 0.00, 10500.00, 0, '2015-07-31', 0, 10500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(737, 0, 25, 'BLUETOOTH HELMET HEADSET - V1098A', 'BLUETOOTH HELMET HEADSET - V1098A', 1, 1, 737, '', 0.00, 3135.00, 2, '2015-07-31', 0, 3135.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(738, 0, 25, 'BOOTS - DAINESE-R EVO-42 BLU/BLK/AN', 'BOOTS - DAINESE-R EVO-42 BLU/BLK/AN', 1, 12, 738, '', 8571.43, 16200.00, 1, '2015-07-31', 0, 16200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(739, 0, 25, 'BOOTS - DAINESE-R EVO-43 BLK', 'BOOTS - DAINESE-R EVO-43 BLK', 1, 12, 739, '', 8571.43, 16200.00, 1, '2015-07-31', 0, 16200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(740, 0, 25, 'BOOTS ALPINESTAR SMX-5 WHITE/BLACK 9.5', 'BOOTS ALPINESTAR SMX-5 WHITE/BLACK 9.5', 1, 12, 740, '', 8571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(741, 0, 25, 'CARTECH TIRE VALVE  - FULL STEEL', 'CARTECH TIRE VALVE  - FULL STEEL', 1, 1, 741, '', 42.41, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(742, 0, 25, 'CARTECH TIRE VALVE - HALF STEEL', 'CARTECH TIRE VALVE - HALF STEEL', 1, 1, 742, '', 22.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(743, 0, 25, 'CARTECH TIRE VALVE - SHORT RUBBER', 'CARTECH TIRE VALVE - SHORT RUBBER', 1, 1, 743, '', 11.16, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(744, 0, 25, 'CHAIN DRIVE D.I.D X-RING GOLD', 'CHAIN DRIVE D.I.D X-RING GOLD', 1, 1, 744, '', 3455.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(745, 0, 25, 'CHAIN RENTHAL-525-130L F4-C391', 'CHAIN RENTHAL-525-130L F4-C391', 1, 1, 745, '', 6071.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(746, 0, 25, 'COOLANT ANTI-FREEZE 05-304115', 'COOLANT ANTI-FREEZE 05-304115', 1, 1, 746, '', 0.00, 480.00, 0, '2015-07-31', 0, 480.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(747, 0, 25, 'CUSTOMIZED SEAT COWL - M795', 'CUSTOMIZED SEAT COWL - M795', 1, 1, 747, '', 4000.00, 5600.00, 2, '2015-07-31', 0, 5600.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(748, 0, 25, 'NATIONAL CYCLE WINDSHIELD N2595', 'NATIONAL CYCLE WINDSHIELD N2595', 1, 1, 748, '', 0.00, 8500.00, 0, '2015-07-31', 0, 8500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(749, 0, 25, 'OIL FILTER LX-S-LT', 'OIL FILTER LX-S-LT', 1, 1, 749, '', 0.00, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(750, 0, 25, 'OIL SEAL DC 43-55-9.5/11.5 MOS DC', 'OIL SEAL DC 43-55-9.5/11.5 MOS DC', 1, 1, 750, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(751, 0, 25, 'OIL SEALDC 48-58-9.5/11.5 MOS DC', 'OIL SEALDC 48-58-9.5/11.5 MOS DC', 1, 1, 751, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(752, 0, 25, 'DKD FORK SLIDER - LOCAL', 'DKD FORK SLIDER - LOCAL', 1, 9, 752, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(753, 0, 25, 'DKD FRAME SLIDER - LOCAL', 'DKD FRAME SLIDER - LOCAL', 1, 9, 753, '', 2500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(754, 0, 25, 'DKD REAR SLIDER - LOCAL', 'DKD REAR SLIDER - LOCAL', 1, 9, 754, '', 1500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(755, 0, 25, 'CUSTOMIZED CENTER STAND ', 'CUSTOMIZED CENTER STAND ', 1, 1, 755, '', 0.00, 5500.00, 0, '2015-07-31', 0, 5500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(756, 0, 25, 'DUCATI LOCAL MUGS - freebies', 'DUCATI LOCAL MUGS - freebies', 2, 1, 756, '', 100.00, 250.00, 2, '2015-07-31', 0, 250.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(757, 0, 25, 'DUCATI LOCAL SHIRTS - RED', 'DUCATI LOCAL SHIRTS - RED', 1, 1, 757, '', 0.00, 400.00, 6, '2015-07-31', 0, 400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(758, 0, 25, 'DUCATI BIKES K&N OIL FILTER-KN153', 'DUCATI BIKES K&N OIL FILTER-KN153', 1, 1, 758, '', 803.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(759, 0, 25, 'DUKE 200 RIM STICKER - KTM RACING', 'DUKE 200 RIM STICKER - KTM RACING', 1, 9, 759, '', 33.48, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(760, 0, 25, 'DUCATI DAVAO T-SHIRT WHITE (SMALL)', 'DUCATI DAVAO T-SHIRT WHITE (SMALL)', 1, 1, 760, '', 0.00, 605.00, 0, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(761, 0, 25, 'DUCATI DAVAO T-SHIRT WHITE (MEDIUM)', 'DUCATI DAVAO T-SHIRT WHITE (MEDIUM)', 1, 1, 761, '', 0.00, 605.00, 0, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(762, 0, 25, 'EMGO OIL FILTER - 10-26955', 'EMGO OIL FILTER - 10-26955', 1, 1, 762, '', 0.00, 560.00, 3, '2015-07-31', 0, 560.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(763, 0, 25, 'EMGO OIL FILTER - 10-26980', 'EMGO OIL FILTER - 10-26980', 1, 1, 763, '', 0.00, 805.00, 4, '2015-07-31', 0, 805.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(764, 0, 25, 'EMGO OIL FILTER - 10-82270', 'EMGO OIL FILTER - 10-82270', 1, 1, 764, '', 0.00, 555.00, 3, '2015-07-31', 0, 555.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(765, 0, 25, 'GLOVES-ALPINE-SMX-2 AC LARGE-RED/WHITE 35', 'GLOVES-ALPINE-SMX-2 AC LARGE-RED/WHITE 35', 1, 12, 765, '', 2142.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(766, 0, 25, 'GLOVES SMX-2 AC RED/WHITE - SMALL ', 'GLOVES SMX-2 AC RED/WHITE - SMALL ', 1, 12, 766, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(767, 0, 25, 'GLOVES CHARGER GLOVES - BLACK/RED LARGE', 'GLOVES CHARGER GLOVES - BLACK/RED LARGE', 1, 12, 767, '', 0.00, 2850.00, 0, '2015-07-31', 0, 2850.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(768, 0, 25, 'GO PRO BATTERY BACPAC - ABPAK001', 'GO PRO BATTERY BACPAC - ABPAK001', 1, 1, 768, '', 1687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(769, 0, 25, 'HANDLEBAR (BLACK)', 'HANDLEBAR (BLACK)', 1, 1, 769, '', 1400.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(770, 0, 25, 'HYM FAM R&G REAR SLIDER - SS0006BK - ', 'HYM FAM R&G REAR SLIDER - SS0006BK - ', 1, 12, 770, '', 2250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(771, 0, 25, 'IGNITION COIL PN:75039006000', 'IGNITION COIL PN:75039006000', 1, 1, 771, '', 0.00, 3850.00, 0, '2015-07-31', 0, 3850.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(772, 0, 25, 'K&N AIR FILTER YA-6001', 'K&N AIR FILTER YA-6001', 1, 1, 772, '', 0.00, 4500.00, 0, '2015-07-31', 0, 4500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(773, 0, 25, 'K&N OIL FILTER - KN155 / (58038005100-KTM)', 'K&N OIL FILTER - KN155 / (58038005100-KTM)', 1, 1, 773, '', 482.14, 836.00, 1, '2015-07-31', 0, 836.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(774, 0, 25, 'K&N OIL FILTER - KN-652', 'K&N OIL FILTER - KN-652', 1, 1, 774, '', 602.68, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(775, 0, 25, 'KWIK PATCHES - PP0 SMALL', 'KWIK PATCHES - PP0 SMALL', 1, 1, 775, '', 3.38, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(776, 0, 25, 'KWIK PATCHES - PP1 MEDIUM', 'KWIK PATCHES - PP1 MEDIUM', 1, 1, 776, '', 5.63, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(777, 0, 25, 'KWIK PATCHES - PP2 LARGE', 'KWIK PATCHES - PP2 LARGE', 1, 1, 777, '', 7.31, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(778, 0, 25, 'KWIK T-VALVE FULL STEEL', 'KWIK T-VALVE FULL STEEL', 1, 1, 778, '', 27.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(779, 0, 25, 'KWIK T-VALVE HALF STEEL', 'KWIK T-VALVE HALF STEEL', 1, 1, 779, '', 12.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(780, 0, 25, 'KWIK T-VALVE RUBBER', 'KWIK T-VALVE RUBBER', 1, 1, 780, '', 7.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(781, 0, 25, 'KWIK WHEEL WEIGHTS - 5G', 'KWIK WHEEL WEIGHTS - 5G', 1, 1, 781, '', 0.83, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(782, 0, 25, 'LEVER ORANGE CLUTCH/BRAKE DUKE200', 'LEVER ORANGE CLUTCH/BRAKE DUKE200', 1, 12, 782, '', 6800.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(783, 0, 25, 'MALOSSI EXHAUST PIPE - DUKE 200', 'MALOSSI EXHAUST PIPE - DUKE 200', 1, 9, 783, '', 0.00, 30800.00, 0, '2015-07-31', 0, 30800.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(784, 0, 25, 'MARUNI CARTECH PATCHES - L3 LARGE', 'MARUNI CARTECH PATCHES - L3 LARGE', 1, 1, 784, '', 11.90, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(785, 0, 25, 'MARUNI CARTECH PATCHES - M2 MEDIUM', 'MARUNI CARTECH PATCHES - M2 MEDIUM', 1, 1, 785, '', 9.82, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(786, 0, 25, 'MARUNI CARTECH PATCHES - S2 SMALL', 'MARUNI CARTECH PATCHES - S2 SMALL', 1, 1, 786, '', 5.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(787, 0, 25, 'MTS1200 PP - R&G FRAME SLIDER', 'MTS1200 PP - R&G FRAME SLIDER', 1, 12, 787, '', 5236.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(788, 0, 25, 'MTS1200 PP - R&G RADIATOR GUARD', 'MTS1200 PP - R&G RADIATOR GUARD', 1, 1, 788, '', 3977.68, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(789, 0, 25, 'KAWASAKI LONG SLEEVE BACK ', 'KAWASAKI LONG SLEEVE BACK ', 1, 1, 789, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(790, 0, 25, 'KTM CDO TSHIRT WHITE - SMALL', 'KTM CDO TSHIRT WHITE - SMALL', 2, 1, 790, '', 128.53, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(791, 0, 25, 'KTM CDO TSHIRT WHITE - MEDIUM ', 'KTM CDO TSHIRT WHITE - MEDIUM ', 2, 1, 791, '', 128.53, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(792, 0, 25, 'T-SHIRT KTM CDO WHITE ', 'T-SHIRT KTM CDO WHITE ', 1, 1, 792, '', 0.00, 605.00, 0, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(793, 0, 41, 'KTM LOCAL MUG - freebies', 'KTM LOCAL MUG - freebies', 2, 1, 793, '', 100.00, 250.00, 2, '2015-07-31', 0, 250.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(794, 0, 25, 'KTM LOCAL SHIRT - freebies', 'KTM LOCAL SHIRT - freebies', 1, 1, 794, '', 145.85, 400.00, 0, '2015-07-31', 0, 400.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(795, 0, 25, 'NACHI BEARING 6005-22 DUKE200', 'NACHI BEARING 6005-22 DUKE200', 1, 1, 795, '', 232.15, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(796, 0, 41, 'KTM LOCAL T-SHIRT ORANGE (M)', 'KTM LOCAL T-SHIRT ORANGE (M)', 2, 1, 796, '', 145.85, 550.00, 1, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(797, 0, 41, 'KTM LOCAL T-SHIRT WHITE (L)', 'KTM LOCAL T-SHIRT WHITE (L)', 2, 1, 797, '', 145.85, 550.00, 1, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(798, 0, 7, 'DUCATI DEALERS PLATE ', 'DUCATI DEALERS PLATE ', 1, 1, 798, '', 80.00, 135.00, 3, '2015-07-31', 0, 135.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(799, 0, 2, 'KTM DEALERS PLATE ', 'KTM DEALERS PLATE ', 1, 1, 799, '', 0.00, 135.00, 8, '2015-07-31', 0, 135.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(800, 0, 23, 'HUSQVARNA DEALERS PLATE ', 'HUSQVARNA DEALERS PLATE ', 1, 1, 800, '', 0.00, 0.00, 2, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(801, 0, 27, 'VESPA DEALERS PLATE ', 'VESPA DEALERS PLATE ', 1, 1, 801, '', 80.00, 135.00, 1, '2015-07-31', 0, 135.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(802, 0, 25, 'VESPA MUG - freebies', 'VESPA MUG - freebies', 1, 1, 802, '', 100.00, 250.00, 3, '2015-07-31', 0, 250.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(803, 0, 25, 'VESPA SHIRT - freebies (S, M, L)', 'VESPA SHIRT - freebies (S, M, L)', 1, 1, 803, '', 150.00, 550.00, 2, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(804, 0, 25, 'VESPA DAVAO T-SHIRT WHITE - LARGE ', 'VESPA DAVAO T-SHIRT WHITE - LARGE ', 1, 1, 804, '', 150.00, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(805, 0, 25, 'VESPA DAVAO T-SHIRT WHITE - SMALL', 'VESPA DAVAO T-SHIRT WHITE - SMALL', 1, 1, 805, '', 150.00, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(806, 0, 25, 'FR 2013 BLACK SHIRT ', 'FR 2013 BLACK SHIRT ', 1, 1, 806, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(807, 0, 25, 'NDC PREMIUM MULTIBRAND TSHIRT BLACK - XL ', 'NDC PREMIUM MULTIBRAND TSHIRT BLACK - XL ', 2, 1, 807, '', 145.85, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(808, 0, 41, 'NDC TSHIRT BLACK - S', 'NDC TSHIRT BLACK - S', 2, 1, 808, '', 0.00, 605.00, 1, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(809, 0, 25, 'NDC TSHIRT BLACK - L', 'NDC TSHIRT BLACK - L', 2, 1, 809, '', 0.00, 605.00, 1, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(810, 0, 25, 'NDC TSHIRT BLACK - XL', 'NDC TSHIRT BLACK - XL', 2, 1, 810, '', 0.00, 605.00, 2, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(811, 0, 25, 'NDC KEYCHAIN ', 'NDC KEYCHAIN ', 2, 1, 811, '', 0.00, 110.00, 195, '2015-07-31', 0, 110.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(812, 0, 25, 'NMBK SHIRT BLACK', 'NMBK SHIRT BLACK', 1, 1, 812, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(813, 0, 25, 'NIKKO HORN - SFD 100-12 CHROME', 'NIKKO HORN - SFD 100-12 CHROME', 1, 1, 813, '', 0.00, 3455.00, 1, '2015-07-31', 0, 3455.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(814, 0, 25, 'OIL FILTER - KN204', 'OIL FILTER - KN204', 1, 1, 814, '', 602.68, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(815, 0, 25, 'OIL FILTER - VESRAH - SF4007', 'OIL FILTER - VESRAH - SF4007', 1, 1, 815, '', 522.32, 902.00, 0, '2015-07-31', 0, 902.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(817, 0, 25, 'OIL FILTER - YAMAHA ELEMENT - SMALL', 'OIL FILTER - YAMAHA ELEMENT - SMALL', 1, 1, 817, '', 522.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(818, 0, 25, 'K&N OIL FILTER - KN 158', 'K&N OIL FILTER - KN 158', 1, 1, 818, '', 0.00, 975.00, 2, '2015-07-31', 0, 975.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(819, 0, 25, 'OIL FILTER KN-158 - 990/1190', 'OIL FILTER KN-158 - 990/1190', 1, 1, 819, '', 562.50, 1100.00, 1, '2015-07-31', 0, 1100.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(820, 0, 25, 'OIL FILTER -YAMAHA VESRAH- SMALL', 'OIL FILTER -YAMAHA VESRAH- SMALL', 1, 1, 820, '', 361.61, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(821, 0, 25, 'PEANUT BULB - MTS1200', 'PEANUT BULB - MTS1200', 1, 1, 821, '', 13.39, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(822, 0, 25, 'ARROW-DARK THUNDER SILENCER - 51510A0N', 'ARROW-DARK THUNDER SILENCER - 51510A0N', 1, 1, 822, '', 6500.00, 25685.00, 0, '2015-07-31', 0, 25685.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(823, 0, 25, 'VANS & HINES MUFFLER ', 'VANS & HINES MUFFLER ', 1, 1, 823, '', 0.00, 41500.00, 0, '2015-07-31', 0, 41500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(824, 0, 25, 'PIPES CUSTOMIZED - SMALL CUSTOMIZED', 'PIPES CUSTOMIZED - SMALL CUSTOMIZED', 1, 1, 824, '', 6500.00, 11200.00, 5, '2015-07-31', 0, 11200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(825, 0, 25, 'R&G RADIATOR GUARD - KTM 125/200 DUKE - RAD0108BK', 'R&G RADIATOR GUARD - KTM 125/200 DUKE - RAD0108BK', 1, 1, 825, '', 0.00, 5060.00, 2, '2015-07-31', 0, 5060.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(826, 0, 25, 'R&G RADIATOR GUARD - KTM 390 DUKE - RAD0164BK', 'R&G RADIATOR GUARD - KTM 390 DUKE - RAD0164BK', 1, 1, 826, '', 0.00, 5940.00, 1, '2015-07-31', 0, 5940.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(827, 0, 25, 'R&G FRAME SLIDER - CP0289BL D200', 'R&G FRAME SLIDER - CP0289BL D200', 1, 12, 827, '', 0.00, 10970.00, 1, '2015-07-31', 0, 10970.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(828, 0, 25, 'R&G FORK SLIDER - FP0106BK D200', 'R&G FORK SLIDER - FP0106BK D200', 1, 12, 828, '', 2290.18, 3635.00, 1, '2015-07-31', 0, 3635.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(829, 0, 25, 'R&G REAR SLIDER - CR0003BK', 'R&G REAR SLIDER - CR0003BK', 1, 12, 829, '', 0.00, 2465.00, 1, '2015-07-31', 0, 2465.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(830, 0, 25, 'R&G FRAME SLIDER AERO CRASH PROTECTOR - CP0343BL', 'R&G FRAME SLIDER AERO CRASH PROTECTOR - CP0343BL', 1, 9, 830, '', 0.00, 9565.00, 1, '2015-07-31', 0, 9565.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(831, 0, 25, 'R&G REAR SPINDLE SLIDERS - SS0006BK', 'R&G REAR SPINDLE SLIDERS - SS0006BK', 1, 9, 831, '', 0.00, 3610.00, 1, '2015-07-31', 0, 3610.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(832, 0, 25, 'R&G REAR SPINDLE SLIDER - SS0026BK', 'R&G REAR SPINDLE SLIDER - SS0026BK', 1, 9, 832, '', 0.00, 3610.00, 0, '2015-07-31', 0, 3610.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(833, 0, 25, 'R&G FORK PROTECTOR - FP0020BK', 'R&G FORK PROTECTOR - FP0020BK', 1, 9, 833, '', 0.00, 4095.00, 0, '2015-07-31', 0, 4095.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(834, 0, 25, 'R&G SHOCK TUBE - SHOCK2BK D200', 'R&G SHOCK TUBE - SHOCK2BK D200', 1, 1, 834, '', 1571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(835, 0, 25, 'R&G SWINGARM SPOOL - CR003BK - D200', 'R&G SWINGARM SPOOL - CR003BK - D200', 1, 12, 835, '', 1607.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(836, 0, 25, 'R&G TAIL TIDY - LP0108BK D200', 'R&G TAIL TIDY - LP0108BK D200', 1, 9, 836, '', 4642.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(837, 0, 25, 'REAR STAND', 'REAR STAND', 1, 1, 837, '', 0.00, 2500.00, 0, '2015-07-31', 0, 2500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(838, 0, 25, 'RECHARGABLE KIT FILTER ', 'RECHARGABLE KIT FILTER ', 1, 1, 838, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(839, 0, 25, 'REDBULL DUKE 200 STICKER', 'REDBULL DUKE 200 STICKER', 1, 9, 839, '', 1919.65, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(840, 0, 25, 'RENTHAL HAND GRIP ', 'RENTHAL HAND GRIP ', 1, 12, 840, '', 0.00, 1155.00, 0, '2015-07-31', 0, 1155.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(841, 0, 25, 'RENTHAL HANDLE BAR - 609-01 FATBAR - BLACK', 'RENTHAL HANDLE BAR - 609-01 FATBAR - BLACK', 1, 1, 841, '', 3928.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(842, 0, 25, 'RENTHAL HANDLE BAR - 609-01 FATBAR - RED', 'RENTHAL HANDLE BAR - 609-01 FATBAR - RED', 1, 1, 842, '', 3928.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(843, 0, 25, 'RENTHAL RISER / BAR MOUNT - CL001', 'RENTHAL RISER / BAR MOUNT - CL001', 1, 1, 843, '', 3142.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(844, 0, 25, 'RENTHAL RISER / BAR MOUNT - CL006', 'RENTHAL RISER / BAR MOUNT - CL006', 1, 1, 844, '', 3142.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(845, 0, 25, 'RENTHAL TWIN WALL HANDLE BAR - BLACK', 'RENTHAL TWIN WALL HANDLE BAR - BLACK', 1, 1, 845, '', 6428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(846, 0, 25, 'RENTHAL TWIN WALL HANDLE BAR - TITANIUM', 'RENTHAL TWIN WALL HANDLE BAR - TITANIUM', 1, 1, 846, '', 6428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(847, 0, 25, 'RUBBER MATTING GTS', 'RUBBER MATTING GTS', 1, 1, 847, '', 0.00, 2000.00, 0, '2015-07-31', 0, 2000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(848, 0, 25, 'RUBBER MATTING LX/S/LT', 'RUBBER MATTING LX/S/LT', 1, 1, 848, '', 0.00, 1680.00, 0, '2015-07-31', 0, 1680.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(849, 0, 25, 'RIZOMA SIDE MIRROR ELLISE (BLACK-RED) - M795', 'RIZOMA SIDE MIRROR ELLISE (BLACK-RED) - M795', 1, 1, 849, '', 0.00, 5445.00, 0, '2015-07-31', 0, 5445.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(850, 0, 25, 'RIZOMA REARWHEEL PROTECTOR - PW204A', 'RIZOMA REARWHEEL PROTECTOR - PW204A', 1, 1, 850, '', 7571.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(851, 0, 25, 'SEAT COWL FOR M-795', 'SEAT COWL FOR M-795', 1, 1, 851, '', 0.00, 2000.00, 0, '2015-07-31', 0, 2000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(852, 0, 25, 'SKF BEARING - 6202-2RS DUKE200', 'SKF BEARING - 6202-2RS DUKE200', 1, 1, 852, '', 178.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(853, 0, 25, 'SKF BEARING - 6302-2RS DUKE200', 'SKF BEARING - 6302-2RS DUKE200', 1, 1, 853, '', 178.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(854, 0, 25, 'RIZOMA SIDE MIRROR ELLISE (PAIR) ', 'RIZOMA SIDE MIRROR ELLISE (PAIR) ', 1, 9, 854, '', 0.00, 5445.00, 2, '2015-07-31', 0, 5445.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(855, 0, 25, 'LOCAL SLIDER DUKE 200 (frame, fork and rear)', 'LOCAL SLIDER DUKE 200 (frame, fork and rear)', 1, 9, 855, '', 0.00, 6380.00, 0, '2015-07-31', 0, 6380.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(857, 0, 25, 'SLIDER FOR DUKE 200/390', 'SLIDER FOR DUKE 200/390', 1, 9, 857, '', 0.00, 4000.00, 0, '2015-07-31', 0, 4000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(858, 0, 25, 'SLIDER FOR M-795', 'SLIDER FOR M-795', 1, 9, 858, '', 0.00, 4000.00, 0, '2015-07-31', 0, 4000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(859, 0, 25, 'SPARKPLUG - IRIDIUM/DENSO - IXU27', 'SPARKPLUG - IRIDIUM/DENSO - IXU27', 1, 1, 859, '', 441.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(860, 0, 25, 'SPARKPLUG NGK - CR8EK - NG3478', 'SPARKPLUG NGK - CR8EK - NG3478', 1, 1, 860, '', 312.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(861, 0, 25, 'SPARKPLUG NGK - CR9EK - NG4548', 'SPARKPLUG NGK - CR9EK - NG4548', 1, 1, 861, '', 312.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(862, 0, 25, 'SPARKPLUG NGK - DCPR8E - NG4339', 'SPARKPLUG NGK - DCPR8E - NG4339', 1, 1, 862, '', 178.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(863, 0, 25, 'SPARKPLUG NGK - LKAR8AI-9 NG6706', 'SPARKPLUG NGK - LKAR8AI-9 NG6706', 1, 1, 863, '', 714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(864, 0, 25, 'SPROCKET SHAFT SEAL RING - 25X37X6', 'SPROCKET SHAFT SEAL RING - 25X37X6', 1, 1, 864, '', 178.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(865, 0, 25, 'STEEL SPACER SLEEVE FAB', 'STEEL SPACER SLEEVE FAB', 1, 1, 865, '', 176.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(866, 0, 25, 'STICKER SET - TBR CONCEPT STORE', 'STICKER SET - TBR CONCEPT STORE', 1, 9, 866, '', 1100.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(867, 0, 25, 'TANK PAD PROTECTOR PROGRIP', 'TANK PAD PROTECTOR PROGRIP', 1, 1, 867, '', 225.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(868, 0, 25, 'TIE DOWN', 'TIE DOWN', 1, 1, 868, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(869, 0, 25, 'TOYO ADTEC SPARKPLUGS - GP22IR', 'TOYO ADTEC SPARKPLUGS - GP22IR', 1, 1, 869, '', 178.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(870, 0, 25, 'SLIDERS CUSTOMIZED DUKE 200', 'SLIDERS CUSTOMIZED DUKE 200', 1, 9, 870, '', 0.00, 6560.00, 1, '2015-07-31', 0, 6560.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(871, 0, 25, 'SLIDERS CUSTOMIZED DUKE 390', 'SLIDERS CUSTOMIZED DUKE 390', 1, 9, 871, '', 0.00, 6560.00, 1, '2015-07-31', 0, 6560.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(872, 0, 25, 'MW MAGAZINES ', 'MW MAGAZINES ', 2, 1, 872, '', 35.71, 150.00, 11, '2015-07-31', 0, 150.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(873, 0, 25, 'COMPUTER TABLE ', 'COMPUTER TABLE ', 1, 1, 873, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(874, 0, 25, 'NETBOOK with CHARGER', 'NETBOOK with CHARGER', 1, 1, 874, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(875, 0, 25, 'NOKIA CELLPHONE', 'NOKIA CELLPHONE', 1, 1, 875, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(876, 0, 25, 'ACERBIS TIE DOWN RATCHET - 021050', 'ACERBIS TIE DOWN RATCHET - 021050', 1, 1, 876, '', 1710.00, 3135.00, 0, '2015-07-31', 0, 3135.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(877, 0, 25, 'TOYO ADTEC SPARKPLUGS - GP22R', 'TOYO ADTEC SPARKPLUGS - GP22R', 1, 1, 877, '', 35.71, 120.00, 200, '2015-07-31', 0, 120.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(878, 0, 25, 'TOYO ADTEC SPARKPLUGS - GP24IR', 'TOYO ADTEC SPARKPLUGS - GP24IR', 1, 1, 878, '', 178.57, 550.00, 120, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(879, 0, 25, 'TOYO ADTEC SPARKPLUGS - GP24R/27R', 'TOYO ADTEC SPARKPLUGS - GP24R/27R', 1, 1, 879, '', 35.71, 120.00, 197, '2015-07-31', 0, 120.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(880, 0, 25, 'TOYO ADTEC SPARKPLUGS - GP25R', 'TOYO ADTEC SPARKPLUGS - GP25R', 1, 1, 880, '', 35.71, 120.00, 0, '2015-07-31', 0, 120.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(881, 0, 25, 'TOYO ADTEC SPARKPLUGS - GP27IR', 'TOYO ADTEC SPARKPLUGS - GP27IR', 1, 1, 881, '', 178.57, 550.00, 57, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(885, 0, 9, 'DUCATI DAVAO T-SHIRT BLACK SMALL ', 'DUCATI DAVAO T-SHIRT BLACK SMALL ', 2, 1, 885, '', 300.00, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(886, 0, 9, 'DUCATI DAVAO T-SHIRT BLACK XL ', 'DUCATI DAVAO T-SHIRT BLACK XL ', 2, 1, 886, '', 300.00, 550.00, 0, '2015-07-31', 0, 550.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(887, 0, 9, 'DUCATI NEW 1ST TEE - 987678846', 'DUCATI NEW 1ST TEE - 987678846', 2, 1, 887, '', 1624.00, 2327.00, 0, '2015-07-31', 0, 2327.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(888, 0, 9, 'DUCATI HYPERMOTARD 2010 1:12 DIE CAST ', 'DUCATI HYPERMOTARD 2010 1:12 DIE CAST ', 2, 1, 888, '', 875.00, 1125.00, 0, '2015-07-31', 0, 1125.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(890, 0, 9, 'BAGS DUCATI SHOULDER - BLACK11 - 986960602', 'BAGS DUCATI SHOULDER - BLACK11 - 986960602', 2, 1, 890, '', 2818.75, 4509.00, 1, '2015-07-31', 0, 4509.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(891, 0, 9, 'BAGS DUCATI SHOULDER BAG - 987678882', 'BAGS DUCATI SHOULDER BAG - 987678882', 2, 1, 891, '', 2857.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(892, 0, 9, 'BAGS DUCATI WAIST BAG - 987678900', 'BAGS DUCATI WAIST BAG - 987678900', 2, 1, 892, '', 1160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(893, 0, 9, 'BELT DUCATI DESMO DIESEL75 - 987679091', 'BELT DUCATI DESMO DIESEL75 - 987679091', 2, 1, 893, '', 3928.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(894, 0, 9, 'BIKE MODEL DIAVEL 1:18 - 987675305', 'BIKE MODEL DIAVEL 1:18 - 987675305', 2, 1, 894, '', 356.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(895, 0, 9, 'BIKE MODEL MONSTER 696 - 987763011', 'BIKE MODEL MONSTER 696 - 987763011', 2, 1, 895, '', 356.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(896, 0, 9, 'BIKE MODEL MULTISTRADA1200 - 987672029', 'BIKE MODEL MULTISTRADA1200 - 987672029', 2, 1, 896, '', 312.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(897, 0, 9, 'BOOTS DUCATI PUMA DESMO V2-41 BK/RE - 981465041', 'BOOTS DUCATI PUMA DESMO V2-41 BK/RE - 981465041', 2, 1, 897, '', 9383.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(900, 0, 9, 'CAP DUCATI CORSE 12 CAP KID - 987672912', 'CAP DUCATI CORSE 12 CAP KID - 987672912', 2, 1, 900, '', 841.07, 1480.00, 1, '2015-07-31', 0, 1480.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(901, 0, 9, 'CAP DUCATI CORSE 12 CAP MAN - 987672911', 'CAP DUCATI CORSE 12 CAP MAN - 987672911', 2, 1, 901, '', 1034.82, 1595.00, 0, '2015-07-31', 0, 1595.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(904, 0, 9, 'GRAPHIC DESMO T.SHIRT LARGE - 987680045', 'GRAPHIC DESMO T.SHIRT LARGE - 987680045', 2, 1, 904, '', 937.50, 1859.00, 1, '2015-07-31', 0, 1859.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(905, 0, 9, 'GRAPHIC DESMO T.SHIRT MEDIUM - 987680044', 'GRAPHIC DESMO T.SHIRT MEDIUM - 987680044', 2, 1, 905, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(906, 0, 9, 'GRAPHIC DESMO T.SHIRT SMALL - 987680043', 'GRAPHIC DESMO T.SHIRT SMALL - 987680043', 2, 1, 906, '', 937.50, 1859.00, 0, '2015-07-31', 0, 1859.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(907, 0, 9, 'GRAPHIC DESMO T.SHIRT XLARGE - 987680046', 'GRAPHIC DESMO T.SHIRT XLARGE - 987680046', 2, 1, 907, '', 937.50, 1859.00, 1, '2015-07-31', 0, 1859.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(908, 0, 9, 'GRAPHIC DESMO T.SHIRT XXLARGE - 987680047', 'GRAPHIC DESMO T.SHIRT XXLARGE - 987680047', 2, 1, 908, '', 937.50, 1859.00, 1, '2015-07-31', 0, 1859.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(909, 0, 9, 'GRAPHIC DESMO T.SHIRT XXXLARGE - 987680048', 'GRAPHIC DESMO T.SHIRT XXXLARGE - 987680048', 2, 1, 909, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(910, 0, 9, 'GYM BAG DUC.CORSE - 987682720', 'GYM BAG DUC.CORSE - 987682720', 2, 1, 910, '', 2767.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(911, 0, 9, 'HELMET BAG - 981017507', 'HELMET BAG - 981017507', 2, 1, 911, '', 3392.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(912, 0, 9, 'HISTORICAL P.SHIRT LARGE - 987679875', 'HISTORICAL P.SHIRT LARGE - 987679875', 2, 1, 912, '', 2026.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(913, 0, 9, 'HISTORICAL P.SHIRT XLARGE - 987679876', 'HISTORICAL P.SHIRT XLARGE - 987679876', 2, 1, 913, '', 2026.79, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(914, 0, 9, 'JACKET REPLICA WINTER - XXLARGE - 987683677', 'JACKET REPLICA WINTER - XXLARGE - 987683677', 2, 1, 914, '', 12321.43, 22770.00, 1, '2015-07-31', 0, 22770.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(916, 0, 9, 'JACKET DUCATI W-PROOF MEDIUM MENS - 982722014', 'JACKET DUCATI W-PROOF MEDIUM MENS - 982722014', 2, 1, 916, '', 2460.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(917, 0, 9, 'JACKET MENS JACK TEX - 981402049', 'JACKET MENS JACK TEX - 981402049', 2, 1, 917, '', 12572.32, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(918, 0, 9, 'JACKET W-PROOF XXL - 981013708', 'JACKET W-PROOF XXL - 981013708', 2, 1, 918, '', 9756.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(919, 0, 9, 'JERSEY DUC.CORSE13 P.SHIRT LARGE - 987679985', 'JERSEY DUC.CORSE13 P.SHIRT LARGE - 987679985', 2, 1, 919, '', 1767.86, 3674.00, 0, '2015-07-31', 0, 3674.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(920, 0, 9, 'JERSEY DUC.CORSE13 P.SHIRT MEDIUM - 987679984', 'JERSEY DUC.CORSE13 P.SHIRT MEDIUM - 987679984', 2, 1, 920, '', 1767.86, 3674.00, 1, '2015-07-31', 0, 3674.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(921, 0, 9, 'JERSEY DUC.CORSE13 P.SHIRT XLARGE - 987679986', 'JERSEY DUC.CORSE13 P.SHIRT XLARGE - 987679986', 2, 1, 921, '', 1767.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(922, 0, 9, 'JERSEY DUC.CORSE13 P.SHIRT XXLARGE - 987679987', 'JERSEY DUC.CORSE13 P.SHIRT XXLARGE - 987679987', 2, 1, 922, '', 1767.86, 3674.00, 1, '2015-07-31', 0, 3674.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(923, 0, 9, 'JERSEY DUC.CORSE13 P.SHIRT XXXLARGE - 987679988', 'JERSEY DUC.CORSE13 P.SHIRT XXXLARGE - 987679988', 2, 1, 923, '', 1767.86, 3674.00, 1, '2015-07-31', 0, 3674.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(924, 0, 9, 'KEYRING DUC.CORSE 12 PVC - 981015006', 'KEYRING DUC.CORSE 12 PVC - 981015006', 2, 1, 924, '', 258.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(925, 0, 9, 'KEYRING DUC.CORSE CHAIN - 987680370', 'KEYRING DUC.CORSE CHAIN - 987680370', 2, 1, 925, '', 678.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(926, 0, 9, 'KEYRING PASS HOLDER - 987672021', 'KEYRING PASS HOLDER - 987672021', 2, 1, 926, '', 223.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(927, 0, 9, 'LIGTHER DUC.CORSE - 987680330', 'LIGTHER DUC.CORSE - 987680330', 2, 1, 927, '', 1250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(929, 0, 9, 'LOGO13 P.SHIRT - MEDIUM - 987679814', 'LOGO13 P.SHIRT - MEDIUM - 987679814', 2, 1, 929, '', 2589.29, 5346.00, 1, '2015-07-31', 0, 5346.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(931, 0, 9, 'LOGO13 P.SHIRT XXLARGE - 987679817', 'LOGO13 P.SHIRT XXLARGE - 987679817', 2, 1, 931, '', 2589.29, 5346.00, 1, '2015-07-31', 0, 5346.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(933, 0, 9, 'MUGS CORSE BLACK - 987674254', 'MUGS CORSE BLACK - 987674254', 2, 1, 933, '', 366.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(935, 0, 9, 'P.SHIRT HISTORICAL MEDIUM - LADY - 987679924', 'P.SHIRT HISTORICAL MEDIUM - LADY - 987679924', 2, 1, 935, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(936, 0, 9, 'P.SHIRT HISTORICAL SMALL - LADY - 987679923', 'P.SHIRT HISTORICAL SMALL - LADY - 987679923', 2, 1, 936, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(939, 0, 9, 'PANIGALE 1199 KEYRING PVC - 987680350', 'PANIGALE 1199 KEYRING PVC - 987680350', 2, 1, 939, '', 258.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(940, 0, 9, 'PANTS DESMO 30-DIESEL - 987678572', 'PANTS DESMO 30-DIESEL - 987678572', 2, 1, 940, '', 7857.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(941, 0, 9, 'PANTS DUCATI STRADA GT - 52 FABRIC - 981005352', 'PANTS DUCATI STRADA GT - 52 FABRIC - 981005352', 2, 1, 941, '', 16337.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(946, 0, 9, 'POLO-SHIRT DUCATI RIVETS - LARGE - BLACK - 986960055', 'POLO-SHIRT DUCATI RIVETS - LARGE - BLACK - 986960055', 2, 1, 946, '', 2732.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(948, 0, 9, 'POLO-SHIRT DUCATIANA / S - RED - 987674213', 'POLO-SHIRT DUCATIANA / S - RED - 987674213', 2, 1, 948, '', 1583.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(949, 0, 9, 'SHOES DUCATI MOTORAZZO 11 - 42 - 986960342', 'SHOES DUCATI MOTORAZZO 11 - 42 - 986960342', 2, 1, 949, '', 4941.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(950, 0, 9, 'SHOES TESTASTRETTA/45 - 987679045', 'SHOES TESTASTRETTA/45 - 987679045', 2, 1, 950, '', 4285.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(951, 0, 9, 'STICKER SET DUCATI - 981004504', 'STICKER SET DUCATI - 981004504', 2, 1, 951, '', 955.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(952, 0, 9, 'SUIT DUCATI RAIN SUIT - RED / LARGE - 982423025', 'SUIT DUCATI RAIN SUIT - RED / LARGE - 982423025', 2, 1, 952, '', 6033.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(954, 0, 9, 'T.SHIRT DUC. D46 WELCOME SMALL RED -987672053', 'T.SHIRT DUC. D46 WELCOME SMALL RED -987672053', 2, 1, 954, '', 0.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(955, 0, 9, 'T.SHIRT DUCATI BOYS L/S - 140 NAVY - 987678845', 'T.SHIRT DUCATI BOYS L/S - 140 NAVY - 987678845', 2, 1, 955, '', 1339.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(956, 0, 9, 'T.SHIRT DUCATI BOYS L/S - 152 NAVY - 987678846', 'T.SHIRT DUCATI BOYS L/S - 152 NAVY - 987678846', 2, 1, 956, '', 1339.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(957, 0, 9, 'T.SHIRT DUCATI BOYS SS12 - 140 RED - 987678825', 'T.SHIRT DUCATI BOYS SS12 - 140 RED - 987678825', 2, 1, 957, '', 1160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(958, 0, 9, 'T.SHIRT DUCATI BOYS SS12 - 152 RED - 987678826', 'T.SHIRT DUCATI BOYS SS12 - 152 RED - 987678826', 2, 1, 958, '', 1160.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(959, 0, 9, 'T.SHIRT DUCATI LOGO SS12 - LARGE/WHITE - 987678795', 'T.SHIRT DUCATI LOGO SS12 - LARGE/WHITE - 987678795', 2, 1, 959, '', 1428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(960, 0, 9, 'T.SHIRT DUCATI LOGO SS12 - XLARGE/WHITE - 987678796', 'T.SHIRT DUCATI LOGO SS12 - XLARGE/WHITE - 987678796', 2, 1, 960, '', 1428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(966, 0, 9, 'T-SHIRT 1198 PANIGALE XLARGE - 987679026', 'T-SHIRT 1198 PANIGALE XLARGE - 987679026', 2, 1, 966, '', 1066.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(967, 0, 9, 'T-SHIRT DIAVEL XLARGE - 987678996', 'T-SHIRT DIAVEL XLARGE - 987678996', 2, 1, 967, '', 1066.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(968, 0, 9, 'T-SHIRT DIAVEL XXLARGE - 987678997', 'T-SHIRT DIAVEL XXLARGE - 987678997', 2, 1, 968, '', 1066.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(969, 0, 9, 'T-SHIRT DIAVEL XXXLARGE - 987678998', 'T-SHIRT DIAVEL XXXLARGE - 987678998', 2, 1, 969, '', 1066.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(970, 0, 9, 'T-SHIRT DUCATI CHECA L - 987679115', 'T-SHIRT DUCATI CHECA L - 987679115', 2, 1, 970, '', 1515.46, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(971, 0, 9, 'T-SHIRT DUCATI CHECA M - 987679114', 'T-SHIRT DUCATI CHECA M - 987679114', 2, 1, 971, '', 1515.46, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(972, 0, 9, 'T-SHIRT DUCATI CHECA XXL - 987679117', 'T-SHIRT DUCATI CHECA XXL - 987679117', 2, 1, 972, '', 1515.46, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(973, 0, 9, 'T-SHIRT DUCATI D46 START KID - 08 - 987673908', 'T-SHIRT DUCATI D46 START KID - 08 - 987673908', 2, 1, 973, '', 1548.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(976, 0, 9, 'T-SHIRT DUCATI DC S/S BLACK - MEDIUM - 987714014', 'T-SHIRT DUCATI DC S/S BLACK - MEDIUM - 987714014', 2, 1, 976, '', 1683.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(979, 0, 9, 'T-SHIRT GRAPHIC CHECKMATE - LARGE - 987680065', 'T-SHIRT GRAPHIC CHECKMATE - LARGE - 987680065', 2, 1, 979, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(980, 0, 9, 'T-SHIRT GRAPHIC CHECKMATE - MEDIUM - 987680064', 'T-SHIRT GRAPHIC CHECKMATE - MEDIUM - 987680064', 2, 1, 980, '', 1089.29, 2200.00, 1, '2015-07-31', 0, 2200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(981, 0, 9, 'T-SHIRT GRAPHIC CHECKMATE - SMALL - 987680063', 'T-SHIRT GRAPHIC CHECKMATE - SMALL - 987680063', 2, 1, 981, '', 1089.29, 2200.00, 1, '2015-07-31', 0, 2200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(982, 0, 9, 'T-SHIRT GRAPHIC CHECKMATE - XL - 987680066', 'T-SHIRT GRAPHIC CHECKMATE - XL - 987680066', 2, 1, 982, '', 1089.29, 2200.00, 2, '2015-07-31', 0, 2200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(983, 0, 9, 'T-SHIRT GRAPHIC CHECKMATE - XXL - 987680067', 'T-SHIRT GRAPHIC CHECKMATE - XXL - 987680067', 2, 1, 983, '', 1089.29, 2200.00, 1, '2015-07-31', 0, 2200.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(984, 0, 9, 'T-SHIRT GRAPHIC CHECKMATE - XXXL - 987680068', 'T-SHIRT GRAPHIC CHECKMATE - XXXL - 987680068', 2, 1, 984, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(985, 0, 9, 'T-SHIRT GRAPHIC DIAVEL - LARGE - 987680075', 'T-SHIRT GRAPHIC DIAVEL - LARGE - 987680075', 2, 1, 985, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(986, 0, 9, 'T-SHIRT GRAPHIC DIAVEL - MEDIUM - 987680074', 'T-SHIRT GRAPHIC DIAVEL - MEDIUM - 987680074', 2, 1, 986, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(987, 0, 9, 'T-SHIRT GRAPHIC DIAVEL - SMALL - 987680073', 'T-SHIRT GRAPHIC DIAVEL - SMALL - 987680073', 2, 1, 987, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(988, 0, 9, 'T-SHIRT GRAPHIC DIAVEL - XL - 987680076', 'T-SHIRT GRAPHIC DIAVEL - XL - 987680076', 2, 1, 988, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(989, 0, 9, 'T-SHIRT GRAPHIC DIAVEL - XXL - 987680077', 'T-SHIRT GRAPHIC DIAVEL - XXL - 987680077', 2, 1, 989, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(990, 0, 9, 'T-SHIRT GRAPHIC DIAVEL - XXXL - 987680078', 'T-SHIRT GRAPHIC DIAVEL - XXXL - 987680078', 2, 1, 990, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(991, 0, 9, 'T-SHIRT GRAPHIC RETRO FLUO - LARGE - 987679935', 'T-SHIRT GRAPHIC RETRO FLUO - LARGE - 987679935', 2, 1, 991, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(992, 0, 9, 'T-SHIRT GRAPHIC RETRO FLUO - MEDIUM - 987679934', 'T-SHIRT GRAPHIC RETRO FLUO - MEDIUM - 987679934', 2, 1, 992, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(993, 0, 9, 'T-SHIRT GRAPHIC RETRO FLUO - SMALL - 987679933', 'T-SHIRT GRAPHIC RETRO FLUO - SMALL - 987679933', 2, 1, 993, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(994, 0, 9, 'T-SHIRT GRAPHIC RETRO FLUO - XL - 987679936', 'T-SHIRT GRAPHIC RETRO FLUO - XL - 987679936', 2, 1, 994, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(995, 0, 9, 'T-SHIRT GRAPHIC RETRO FLUO - XXL - 987679937', 'T-SHIRT GRAPHIC RETRO FLUO - XXL - 987679937', 2, 1, 995, '', 1089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(996, 0, 9, 'T-SHIRT GRAPHIC SUPERQUADRO - LARGE - 987680055', 'T-SHIRT GRAPHIC SUPERQUADRO - LARGE - 987680055', 2, 1, 996, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(997, 0, 9, 'T-SHIRT GRAPHIC SUPERQUADRO - MEDIUM - 987680054', 'T-SHIRT GRAPHIC SUPERQUADRO - MEDIUM - 987680054', 2, 1, 997, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(998, 0, 9, 'T-SHIRT GRAPHIC SUPERQUADRO - SMALL - 987680053', 'T-SHIRT GRAPHIC SUPERQUADRO - SMALL - 987680053', 2, 1, 998, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(999, 0, 9, 'T-SHIRT GRAPHIC SUPERQUADRO - XL - 987680056', 'T-SHIRT GRAPHIC SUPERQUADRO - XL - 987680056', 2, 1, 999, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1000, 0, 9, 'T-SHIRT GRAPHIC SUPERQUADRO - XXL - 987680057', 'T-SHIRT GRAPHIC SUPERQUADRO - XXL - 987680057', 2, 1, 1000, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1001, 0, 9, 'T-SHIRT GRAPHIC SUPERQUADRO - XXXL - 987680058', 'T-SHIRT GRAPHIC SUPERQUADRO - XXXL - 987680058', 2, 1, 1001, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1002, 0, 9, 'T-SHIRT HYPERMOTARD -MEDIUM - 987679074', 'T-SHIRT HYPERMOTARD -MEDIUM - 987679074', 2, 1, 1002, '', 1066.96, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1006, 0, 9, 'T-SHIRT REPLICA GP 12 XXLARGE - 987678637', 'T-SHIRT REPLICA GP 12 XXLARGE - 987678637', 2, 1, 1006, '', 2424.11, 4265.00, 1, '2015-07-31', 0, 4265.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1007, 0, 9, 'T-SHIRT PUMA MANS LOGO / S - BLUE - 981014703', 'T-SHIRT PUMA MANS LOGO / S - BLUE - 981014703', 2, 1, 1007, '', 1454.46, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1010, 0, 9, 'DUCATI TWIN HELMET XL BLACK - 981016306', 'DUCATI TWIN HELMET XL BLACK - 981016306', 2, 1, 1010, '', 16918.75, 29777.00, 0, '2015-07-31', 0, 29777.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1011, 0, 9, 'BIKE MODEL 1199 PANIGALE - 987682551', 'BIKE MODEL 1199 PANIGALE - 987682551', 2, 1, 1011, '', 343.75, 605.00, 1, '2015-07-31', 0, 605.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1012, 0, 9, 'BOOTS DUCATI SPORT 44 - 981020344', 'BOOTS DUCATI SPORT 44 - 981020344', 2, 1, 1012, '', 0.00, 17050.00, 1, '2015-07-31', 0, 17050.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1013, 0, 9, 'BOOTS DUCATI COMPANY 46 - 981020446', 'BOOTS DUCATI COMPANY 46 - 981020446', 2, 1, 1013, '', 5107.14, 10780.00, 1, '2015-07-31', 0, 10780.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1014, 0, 9, 'BOOTS DUCATI COMPANY 45 - 981020445', 'BOOTS DUCATI COMPANY 45 - 981020445', 2, 1, 1014, '', 5107.14, 9515.00, 1, '2015-07-31', 0, 9515.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1015, 0, 9, 'BOOTS DUCATI COMPANY 42 - 981020442', 'BOOTS DUCATI COMPANY 42 - 981020442', 2, 1, 1015, '', 5107.14, 9515.00, 1, '2015-07-31', 0, 9515.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1016, 0, 9, 'BOOTS DUCATI STRADA 42 - 981020142', 'BOOTS DUCATI STRADA 42 - 981020142', 2, 1, 1016, '', 8995.54, 16830.00, 1, '2015-07-31', 0, 16830.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1017, 0, 9, 'BOOTS DUCATI STRADA 43 - 981020443', 'BOOTS DUCATI STRADA 43 - 981020443', 2, 1, 1017, '', 8995.54, 9515.00, 1, '2015-07-31', 0, 9515.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1018, 0, 9, 'BOOTS DUCATI COMPANY 44 - 981020444', 'BOOTS DUCATI COMPANY 44 - 981020444', 2, 1, 1018, '', 8995.54, 9515.00, 1, '2015-07-31', 0, 9515.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1019, 0, 9, 'BOOTS ROADSTER - V3 GT46-BLACK/WHITE - 981017946', 'BOOTS ROADSTER - V3 GT46-BLACK/WHITE - 981017946', 2, 1, 1019, '', 8281.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1020, 0, 9, 'CAP DUCATI REPLICA - 987683640', 'CAP DUCATI REPLICA - 987683640', 2, 1, 1020, '', 1428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1021, 0, 9, 'GLOVES PITLANE LARGE - 981015045', 'GLOVES PITLANE LARGE - 981015045', 2, 1, 1021, '', 1887.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1022, 0, 9, 'GLOVES STRADA FIT GT MEDIUM BLACK - 981006014', 'GLOVES STRADA FIT GT MEDIUM BLACK - 981006014', 2, 1, 1022, '', 9731.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1023, 0, 9, 'HELMET - TRICOLORE XLARGE - 981018496', 'HELMET - TRICOLORE XLARGE - 981018496', 2, 1, 1023, '', 32910.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1024, 0, 9, 'JACKET DUCATI HI-TECH 56 - 981020956', 'JACKET DUCATI HI-TECH 56 - 981020956', 2, 1, 1024, '', 18821.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1025, 0, 9, 'KEY RING DUCATI MECCANICA LEATHER 2011 - 981012814', 'KEY RING DUCATI MECCANICA LEATHER 2011 - 981012814', 2, 1, 1025, '', 448.21, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1026, 0, 9, 'KEY RING LEATHER HOLDER 80S SS - 981012828', 'KEY RING LEATHER HOLDER 80S SS - 981012828', 2, 1, 1026, '', 683.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1029, 0, 9, 'MANUAL DIAVEL - 91471121A - MY11', 'MANUAL DIAVEL - 91471121A - MY11', 2, 1, 1029, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1030, 0, 9, 'MANUAL DIAVEL - 91471121X', 'MANUAL DIAVEL - 91471121X', 2, 1, 1030, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1031, 0, 9, 'MANUAL HYM 796 - CD - 91471071A', 'MANUAL HYM 796 - CD - 91471071A', 2, 1, 1031, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1032, 0, 9, 'MANUAL MONSTER 696 - CD - 91471081A', 'MANUAL MONSTER 696 - CD - 91471081A', 2, 1, 1032, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1033, 0, 9, 'MANUAL MR1100EVO-ABS - MY11', 'MANUAL MR1100EVO-ABS - MY11', 2, 1, 1033, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1034, 0, 9, 'MANUAL MTS1200 ABS - CD - 91371731A', 'MANUAL MTS1200 ABS - CD - 91371731A', 2, 1, 1034, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1035, 0, 9, 'MANUAL STREETFIGHTER 1098S - CD - 91471031A', 'MANUAL STREETFIGHTER 1098S - CD - 91471031A', 2, 1, 1035, '', 2907.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1036, 0, 9, 'MUG-DUCATI-COMPANY SS-6 CUP KIT BLACK - white 981012809', 'MUG-DUCATI-COMPANY SS-6 CUP KIT BLACK - white 981012809', 2, 9, 1036, '', 1819.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1037, 0, 9, 'P.SHIRT COMPANY 14 BLACK - MEDIUM - 987686214', 'P.SHIRT COMPANY 14 BLACK - MEDIUM - 987686214', 2, 1, 1037, '', 1681.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1038, 0, 9, 'P.SHIRT COMPANY 14 BLACK - SMALL - 987686213', 'P.SHIRT COMPANY 14 BLACK - SMALL - 987686213', 2, 1, 1038, '', 1681.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1039, 0, 9, 'P.SHIRT COMPANY 14 BLACK - LARGE - 987686225', 'P.SHIRT COMPANY 14 BLACK - LARGE - 987686225', 2, 1, 1039, '', 1681.25, 2970.00, 1, '2015-07-31', 0, 2970.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1040, 0, 9, 'P.SHIRT COMPANY 14 BLACK - XLARGE - 987686216', 'P.SHIRT COMPANY 14 BLACK - XLARGE - 987686216', 2, 1, 1040, '', 1681.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1041, 0, 9, 'P.SHIRT COMPANY 14 BLACK - XXLARGE - 987686217', 'P.SHIRT COMPANY 14 BLACK - XXLARGE - 987686217', 2, 1, 1041, '', 1681.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1042, 0, 9, 'P.SHIRT COMPANY 14 LADY BLACK SMALL - 987686223', 'P.SHIRT COMPANY 14 LADY BLACK SMALL - 987686223', 2, 1, 1042, '', 1508.04, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1043, 0, 9, 'SWEATSHIRT COMPANY 12 - XLARGE BLACK - 987674156', 'SWEATSHIRT COMPANY 12 - XLARGE BLACK - 987674156', 2, 1, 1043, '', 3642.86, 5830.00, 0, '2015-07-31', 0, 5830.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1044, 0, 9, 'T.SHIRT DUC.CORSE12 SMALL-SINGLET - 987673013', 'T.SHIRT DUC.CORSE12 SMALL-SINGLET - 987673013', 2, 1, 1044, '', 1035.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1045, 0, 9, 'T.SHIRT GRAPHIC LARGE DASHBOARD - 987680035', 'T.SHIRT GRAPHIC LARGE DASHBOARD - 987680035', 2, 1, 1045, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1046, 0, 9, 'T.SHIRT GRAPHIC RIDING LARGE RED - 987680025', 'T.SHIRT GRAPHIC RIDING LARGE RED - 987680025', 2, 1, 1046, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1047, 0, 9, 'T.SHIRT GRAPHIC RIDING MEDIUM RED - 987680024', 'T.SHIRT GRAPHIC RIDING MEDIUM RED - 987680024', 2, 1, 1047, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1048, 0, 9, 'T.SHIRT GRAPHIC RIDING XLARGE RED - 987680026', 'T.SHIRT GRAPHIC RIDING XLARGE RED - 987680026', 2, 1, 1048, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1049, 0, 9, 'T.SHIRT GRAPHIC RIDING XXLARGE RED - 987680027', 'T.SHIRT GRAPHIC RIDING XXLARGE RED - 987680027', 2, 1, 1049, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1050, 0, 9, 'T.SHIRT GRAPHIC XLARGE DASHBOARD - 987680036', 'T.SHIRT GRAPHIC XLARGE DASHBOARD - 987680036', 2, 1, 1050, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1051, 0, 9, 'T.SHIRT GRAPHIC XXLARGE DASHBOARD - 987680037', 'T.SHIRT GRAPHIC XXLARGE DASHBOARD - 987680037', 2, 1, 1051, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1052, 0, 9, 'T.SHIRT GRAPHIC XXXLARGE DASHBOARD - 987680038', 'T.SHIRT GRAPHIC XXXLARGE DASHBOARD - 987680038', 2, 1, 1052, '', 937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1053, 0, 9, 'TSHIRT GRAPHIC BATTLE OF THE TWINS -XXLARGE - 987684097', 'TSHIRT GRAPHIC BATTLE OF THE TWINS -XXLARGE - 987684097', 2, 1, 1053, '', 1062.50, 1980.00, 1, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1054, 0, 9, 'TSHIRT GRAPHIC BATTLE OF THE TWINS -LARGE - 987684095', 'TSHIRT GRAPHIC BATTLE OF THE TWINS -LARGE - 987684095', 2, 1, 1054, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1055, 0, 9, 'TSHIRT GRAPHIC CORDOLO XLARGE - 987684046', 'TSHIRT GRAPHIC CORDOLO XLARGE - 987684046', 2, 1, 1055, '', 1062.50, 1980.00, 1, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1056, 0, 9, 'TSHIRT GRAPHIC CORDOLO XXXLARGE - 987684048', 'TSHIRT GRAPHIC CORDOLO XXXLARGE - 987684048', 2, 1, 1056, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1057, 0, 9, 'TSHIRT GRAPHIC CRAZY COLORS - XLARGE - 987684406', 'TSHIRT GRAPHIC CRAZY COLORS - XLARGE - 987684406', 2, 1, 1057, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1058, 0, 9, 'TSHIRT GRAPHIC KID 2/4 SPRINT - 987684304', 'TSHIRT GRAPHIC KID 2/4 SPRINT - 987684304', 2, 1, 1058, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1059, 0, 9, 'TSHIRT GRAPHIC KID 2/4 EMBLEMA - 987684504', 'TSHIRT GRAPHIC KID 2/4 EMBLEMA - 987684504', 2, 1, 1059, '', 1241.07, 2310.00, 1, '2015-07-31', 0, 2310.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1060, 0, 9, 'TSHIRT GRAPHIC KID 4/6 EMBLEMA - 987684506', 'TSHIRT GRAPHIC KID 4/6 EMBLEMA - 987684506', 2, 1, 1060, '', 1241.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1061, 0, 9, 'TSHIRT GRAPHIC KID 8/10 SPRINT - 987684310', 'TSHIRT GRAPHIC KID 8/10 SPRINT - 987684310', 2, 1, 1061, '', 1062.50, 1980.00, 1, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1062, 0, 9, 'TSHIRT GRAPHIC KID 6/8 SPRINT - 987684308', 'TSHIRT GRAPHIC KID 6/8 SPRINT - 987684308', 2, 1, 1062, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1063, 0, 9, 'TSHIRT GRAPHIC LESS IS MORE XLARGE - 987682846', 'TSHIRT GRAPHIC LESS IS MORE XLARGE - 987682846', 2, 1, 1063, '', 1535.71, 2860.00, 1, '2015-07-31', 0, 2860.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1064, 0, 9, 'TSHIRT GRAPHIC LESS IS MORE LARGE - 987682845', 'TSHIRT GRAPHIC LESS IS MORE LARGE - 987682845', 2, 1, 1064, '', 1535.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1065, 0, 9, 'TSHIRT GRAPHIC LESS IS MORE MEDIUM - 987682844', 'TSHIRT GRAPHIC LESS IS MORE MEDIUM - 987682844', 2, 1, 1065, '', 1535.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1066, 0, 9, 'TSHIRT GRAPHIC LOVE LADY MEDIUM - 987684224', 'TSHIRT GRAPHIC LOVE LADY MEDIUM - 987684224', 2, 1, 1066, '', 1062.50, 1980.00, 1, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1067, 0, 9, 'TSHIRT GRAPHIC RACE TRACK MEDIUM - 987684034', 'TSHIRT GRAPHIC RACE TRACK MEDIUM - 987684034', 2, 1, 1067, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1068, 0, 9, 'TSHIRT GRAPHIC RACE TRACK XLARGE - 987684036', 'TSHIRT GRAPHIC RACE TRACK XLARGE - 987684036', 2, 1, 1068, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1069, 0, 9, 'TSHIRT GRAPHIC RACE TRACK XXXLARGE - 987684038', 'TSHIRT GRAPHIC RACE TRACK XXXLARGE - 987684038', 2, 1, 1069, '', 1062.50, 1980.00, 0, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1070, 0, 9, 'TSHIRT GRAPHIC RUMBLING HEART -MEDIUM - 987684214', 'TSHIRT GRAPHIC RUMBLING HEART -MEDIUM - 987684214', 2, 1, 1070, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1071, 0, 9, 'TSHIRT LONG JOURNEY - XLARGE - 987682856', 'TSHIRT LONG JOURNEY - XLARGE - 987682856', 2, 1, 1071, '', 1535.71, 2860.00, 0, '2015-07-31', 0, 2860.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1072, 0, 9, 'TSHIRT LONG JOURNEY - XXLARGE - 987682857', 'TSHIRT LONG JOURNEY - XXLARGE - 987682857', 2, 1, 1072, '', 1535.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1073, 0, 9, 'TSHIRT MONSTER ANNIVERSARY MEDIUM - 987684064', 'TSHIRT MONSTER ANNIVERSARY MEDIUM - 987684064', 2, 1, 1073, '', 1062.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1074, 0, 9, 'TSHIRT MONSTER ANNIVERSARY XLARGE - 987684066', 'TSHIRT MONSTER ANNIVERSARY XLARGE - 987684066', 2, 1, 1074, '', 1062.50, 1980.00, 1, '2015-07-31', 0, 1980.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1086, 0, 1, 'KTM JACKET MEDIUM ORANGE / BLACK ', 'KTM JACKET MEDIUM ORANGE / BLACK ', 2, 1, 1086, '', 0.00, 5525.00, 1, '2015-07-31', 0, 5525.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1087, 0, 1, 'KTM STRAP TANK BAG - 75012919000', 'KTM STRAP TANK BAG - 75012919000', 2, 1, 1087, '', 5300.00, 8165.00, 1, '2015-07-31', 0, 8165.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1088, 0, 1, 'KEY HOLDER VINYL KTM - 019484', 'KEY HOLDER VINYL KTM - 019484', 2, 1, 1088, '', 42.00, 105.00, 0, '2015-07-31', 0, 105.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1089, 0, 1, 'KTM RC8 1:12 ', 'KTM RC8 1:12 ', 2, 1, 1089, '', 725.00, 1010.00, 0, '2015-07-31', 0, 1010.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1090, 0, 1, 'KTM CAP # 1 (BLACK) 021626', 'KTM CAP # 1 (BLACK) 021626', 2, 1, 1090, '', 0.00, 435.00, 3, '2015-07-31', 0, 435.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1091, 0, 1, 'KTM CAP # 2 (BLACK)', 'KTM CAP # 2 (BLACK)', 2, 1, 1091, '', 0.00, 435.00, 2, '2015-07-31', 0, 435.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1092, 0, 1, 'KTM CAP # 2 (ORANGE) ', 'KTM CAP # 2 (ORANGE) ', 2, 1, 1092, '', 0.00, 435.00, 1, '2015-07-31', 0, 435.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1093, 0, 1, 'KTM CAP # 3 (BLACK/ORANGE)', 'KTM CAP # 3 (BLACK/ORANGE)', 2, 1, 1093, '', 0.00, 385.00, 0, '2015-07-31', 0, 385.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1094, 0, 1, 'KTM RTR TSHIRT ORANGE - M', 'KTM RTR TSHIRT ORANGE - M', 2, 1, 1094, '', 450.00, 880.00, 5, '2015-07-31', 0, 880.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1095, 0, 1, 'KTM RTR TSHIRT ORANGE - L', 'KTM RTR TSHIRT ORANGE - L', 2, 1, 1095, '', 450.00, 880.00, 9, '2015-07-31', 0, 880.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1096, 0, 1, 'KTM RTR TSHIRT ORANGE - XL', 'KTM RTR TSHIRT ORANGE - XL', 2, 1, 1096, '', 450.00, 880.00, 5, '2015-07-31', 0, 880.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1097, 0, 1, 'KTM RTR TSHIRT BLACK - M', 'KTM RTR TSHIRT BLACK - M', 2, 1, 1097, '', 450.00, 880.00, 1, '2015-07-31', 0, 880.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1098, 0, 1, 'KTM RTR TSHIRT BLACK - L', 'KTM RTR TSHIRT BLACK - L', 2, 1, 1098, '', 450.00, 880.00, 2, '2015-07-31', 0, 880.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1099, 0, 1, 'KTM RTR TSHIRT BLACK - XL', 'KTM RTR TSHIRT BLACK - XL', 2, 1, 1099, '', 450.00, 880.00, 2, '2015-07-31', 0, 880.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1100, 0, 1, 'KTM CAP (BLACK) ', 'KTM CAP (BLACK) ', 2, 1, 1100, '', 292.00, 510.00, 0, '2015-07-31', 0, 510.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1101, 0, 1, 'KTM CAP (ORANGE / BLACK)', 'KTM CAP (ORANGE / BLACK)', 2, 1, 1101, '', 292.00, 510.00, 0, '2015-07-31', 0, 510.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1102, 0, 1, 'KTM CAP (WHITE / GREY) ', 'KTM CAP (WHITE / GREY) ', 2, 1, 1102, '', 292.00, 510.00, 0, '2015-07-31', 0, 510.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1103, 0, 1, 'MECHANIC PANTS SHORT / MEDIUM - 3PW105223', 'MECHANIC PANTS SHORT / MEDIUM - 3PW105223', 2, 1, 1103, '', 0.00, 4510.00, 1, '2015-07-31', 0, 4510.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1104, 0, 1, 'MECHANIC PANTS SHORT / LARGE - 3PW105224', 'MECHANIC PANTS SHORT / LARGE - 3PW105224', 2, 1, 1104, '', 0.00, 4510.00, 1, '2015-07-31', 0, 4510.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1105, 0, 1, 'MERCHANDISE - BEACH SANDALS 39/40- 3PW127152', 'MERCHANDISE - BEACH SANDALS 39/40- 3PW127152', 2, 1, 1105, '', 812.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1106, 0, 1, 'NECKPAD NECKBRACE L/XL STX - 3PW111054', 'NECKPAD NECKBRACE L/XL STX - 3PW111054', 2, 1, 1106, '', 19785.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1107, 0, 1, 'PANTS KTM PURE-ADVENTURE - 3PW111232-30', 'PANTS KTM PURE-ADVENTURE - 3PW111232-30', 2, 1, 1107, '', 11071.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1108, 0, 1, 'POLO SHIRT TEAM MEDIUM - 3PW085633', 'POLO SHIRT TEAM MEDIUM - 3PW085633', 2, 1, 1108, '', 2644.64, 3982.00, 1, '2015-07-31', 0, 3982.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1109, 0, 1, 'POLO SHIRT BLACK MEDIUM - 3B85673', 'POLO SHIRT BLACK MEDIUM - 3B85673', 2, 1, 1109, '', 2644.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1110, 0, 1, 'POLO SHIRT BLACK X-BOW - MEDIUM - 3X135614', 'POLO SHIRT BLACK X-BOW - MEDIUM - 3X135614', 2, 1, 1110, '', 2714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1111, 0, 1, 'POLO SHIRT BLACK X-BOW LARGE - 3X135615', 'POLO SHIRT BLACK X-BOW LARGE - 3X135615', 2, 1, 1111, '', 2714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1112, 0, 1, 'POLO SHIRT BLACK X-BOW XLARGE - 3X135616', 'POLO SHIRT BLACK X-BOW XLARGE - 3X135616', 2, 1, 1112, '', 2714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1113, 0, 1, 'POLO SHIRT GIRLS TEAM - MEDIUM - 3PW088623', 'POLO SHIRT GIRLS TEAM - MEDIUM - 3PW088623', 2, 1, 1113, '', 2139.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1114, 0, 1, 'POLO SHIRT WHITE LOGO XXLARGE - 3PW125666', 'POLO SHIRT WHITE LOGO XXLARGE - 3PW125666', 2, 1, 1114, '', 2544.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1115, 0, 1, 'POLOSHIRT LARGE GIRLS TEAM - 3PW088614', 'POLOSHIRT LARGE GIRLS TEAM - 3PW088614', 2, 1, 1115, '', 3142.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1116, 0, 1, 'RADICAL X GLOVES BLK 14 L/10 - 3PW1417404', 'RADICAL X GLOVES BLK 14 L/10 - 3PW1417404', 2, 1, 1116, '', 4785.71, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1118, 0, 1, 'SWEATSHIRT HOODIE BLOCKER - XLARGE - 3PW136415', 'SWEATSHIRT HOODIE BLOCKER - XLARGE - 3PW136415', 2, 1, 1118, '', 3642.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1119, 0, 1, 'SWEATSHIRT SPLATTER HOODED/MEDIUM-3PW116413', 'SWEATSHIRT SPLATTER HOODED/MEDIUM-3PW116413', 2, 1, 1119, '', 3428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1120, 0, 1, 'SWEATSHIRT SPLATTER HOODED/SMALL-3PW116412', 'SWEATSHIRT SPLATTER HOODED/SMALL-3PW116412', 2, 1, 1120, '', 3428.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1121, 0, 1, 'TEE  EMBLEM TEE - LARGE - 3PW106614', 'TEE  EMBLEM TEE - LARGE - 3PW106614', 2, 1, 1121, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1122, 0, 1, 'TEE  EMBLEM TEE - MEDIUM - 3PW106613', 'TEE  EMBLEM TEE - MEDIUM - 3PW106613', 2, 1, 1122, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1123, 0, 1, 'TEE DOODLE/SMALL - 3PW116682', 'TEE DOODLE/SMALL - 3PW116682', 2, 1, 1123, '', 1440.18, 2310.00, 0, '2015-07-31', 0, 2310.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1124, 0, 1, 'TEE DOODLE W - M - 3PW116683', 'TEE DOODLE W - M - 3PW116683', 2, 1, 1124, '', 1440.18, 2020.00, 0, '2015-07-31', 0, 2020.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1125, 0, 1, 'TEE DOODLE W - XL - 3PW116685', 'TEE DOODLE W - XL - 3PW116685', 2, 1, 1125, '', 1440.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1126, 0, 1, 'TEE ISDE 1986 - LARGE - 3PW126634', 'TEE ISDE 1986 - LARGE - 3PW126634', 2, 1, 1126, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1127, 0, 1, 'TEE ISDE 1986 - MEDIUM - 3PW126633', 'TEE ISDE 1986 - MEDIUM - 3PW126633', 2, 1, 1127, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1128, 0, 1, 'TEE ISDE 1986 - XLARGE - 3PW126635', 'TEE ISDE 1986 - XLARGE - 3PW126635', 2, 1, 1128, '', 1714.29, 2640.00, 1, '2015-07-31', 0, 2640.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1129, 0, 1, 'TEE ISDE 1986 - XXLARGE - 3PW126636', 'TEE ISDE 1986 - XXLARGE - 3PW126636', 2, 1, 1129, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1130, 0, 1, 'TEE LARGE ORANGE LOGO DOTS - 3PW125624', 'TEE LARGE ORANGE LOGO DOTS - 3PW125624', 2, 1, 1130, '', 1406.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1131, 0, 1, 'TEE MATRIX MEDIUM - 3PW116613', 'TEE MATRIX MEDIUM - 3PW116613', 2, 1, 1131, '', 1441.07, 2020.00, 1, '2015-07-31', 0, 2020.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1132, 0, 1, 'TEE MATRIX LARGE - 3PW116614', 'TEE MATRIX LARGE - 3PW116614', 2, 1, 1132, '', 1441.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1133, 0, 1, 'TEE MOOSE RUN - MEDIUM - 3PW126653', 'TEE MOOSE RUN - MEDIUM - 3PW126653', 2, 1, 1133, '', 1540.18, 2530.00, 0, '2015-07-31', 0, 2530.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1134, 0, 1, 'TEE MOOSE RUN - LARGE - 3PW126654', 'TEE MOOSE RUN - LARGE - 3PW126654', 2, 1, 1134, '', 1540.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1135, 0, 1, 'TEE MOOSE RUN - XLARGE - 3PW126655', 'TEE MOOSE RUN - XLARGE - 3PW126655', 2, 1, 1135, '', 1540.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1136, 0, 1, 'TEE MOOSE RUN - XXLARGE - 3PW126656', 'TEE MOOSE RUN - XXLARGE - 3PW126656', 2, 1, 1136, '', 1540.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1137, 0, 1, 'TEE MOTORCYCLES - LARGE - 3PW126664', 'TEE MOTORCYCLES - LARGE - 3PW126664', 2, 1, 1137, '', 1540.18, 2530.00, 1, '2015-07-31', 0, 2530.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1138, 0, 1, 'TEE MOTORCYCLES - XXLARGE - 3PW126666', 'TEE MOTORCYCLES - XXLARGE - 3PW126666', 2, 1, 1138, '', 1540.18, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1139, 0, 1, 'TEE NAVY WHITE - LARGE - 3PW125634', 'TEE NAVY WHITE - LARGE - 3PW125634', 2, 1, 1139, '', 1406.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1140, 0, 1, 'TEE NAVY WHITE - XLARGE - 3PW125635', 'TEE NAVY WHITE - XLARGE - 3PW125635', 2, 1, 1140, '', 1406.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1141, 0, 1, 'TEE NAVY WHITE - XXLARGE - 3PW125636', 'TEE NAVY WHITE - XXLARGE - 3PW125636', 2, 1, 1141, '', 1406.25, 2310.00, 1, '2015-07-31', 0, 2310.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1142, 0, 1, 'TEE ORANGE RACING TEE MEDIUM - 3B85643', 'TEE ORANGE RACING TEE MEDIUM - 3B85643', 2, 1, 1142, '', 1214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1143, 0, 1, 'TEE RACEPACK - MEDIUM - 3PW105643', 'TEE RACEPACK - MEDIUM - 3PW105643', 2, 1, 1143, '', 1406.25, 2600.00, 1, '2015-07-31', 0, 2600.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1144, 0, 1, 'TEE RACEPACK - LARGE - 3PW105644', 'TEE RACEPACK - LARGE - 3PW105644', 2, 1, 1144, '', 2089.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1145, 0, 1, 'TEE SPLATTER MEDIUM - 3PW116633', 'TEE SPLATTER MEDIUM - 3PW116633', 2, 1, 1145, '', 1442.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1146, 0, 1, 'TEE SPLATTER TEE /S - 3PW116632', 'TEE SPLATTER TEE /S - 3PW116632', 2, 1, 1146, '', 1441.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1147, 0, 1, 'TEE TECHLOGO/SMALL - 3PW116622', 'TEE TECHLOGO/SMALL - 3PW116622', 2, 1, 1147, '', 900.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1148, 0, 1, 'TEE WHITE RACING MEDIUM - 3B85653', 'TEE WHITE RACING MEDIUM - 3B85653', 2, 1, 1148, '', 1142.86, 1760.00, 1, '2015-07-31', 0, 1760.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1149, 0, 1, 'TEE WHITE RACING XLARGE - 3B85655', 'TEE WHITE RACING XLARGE - 3B85655', 2, 1, 1149, '', 1214.28, 1870.00, 1, '2015-07-31', 0, 1870.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1150, 0, 1, 'TEE WELTMEISTER - MEDIUM - 3PW126623', 'TEE WELTMEISTER - MEDIUM - 3PW126623', 2, 1, 1150, '', 1714.29, 2640.00, 1, '2015-07-31', 0, 2640.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1151, 0, 1, 'TEE WELTMEISTER - LARGE - 3PW126624', 'TEE WELTMEISTER - LARGE - 3PW126624', 2, 1, 1151, '', 1714.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1152, 0, 1, 'TEE XLARGE ORANGE LOGO DOTS - 3PW125625', 'TEE XLARGE ORANGE LOGO DOTS - 3PW125625', 2, 1, 1152, '', 1406.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1177, 0, 12, 'BOOTS - ALPINESTARS - SUPERTECH R-9 WHT/BLACK VENT - 44', 'BOOTS - ALPINESTARS - SUPERTECH R-9 WHT/BLACK VENT - 44', 2, 12, 1177, '', 19285.71, 27000.00, 1, '2015-07-31', 0, 27000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1178, 0, 12, 'STRICKER AIR PANTS - RED/BLACK/WHITE-SMALL ', 'STRICKER AIR PANTS - RED/BLACK/WHITE-SMALL ', 2, 1, 1178, '', 0.00, 10010.00, 1, '2015-07-31', 0, 10010.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1179, 0, 12, 'T-GP PRO JACKET - BLACK ANTHRACITE - SMALL ', 'T-GP PRO JACKET - BLACK ANTHRACITE - SMALL ', 2, 1, 1179, '', 0.00, 19405.00, 1, '2015-07-31', 0, 19405.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1180, 0, 12, 'STRICKER AIR PANTS - BLACK - SMALL ', 'STRICKER AIR PANTS - BLACK - SMALL ', 2, 1, 1180, '', 0.00, 20020.00, 1, '2015-07-31', 0, 20020.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1181, 0, 12, 'ALPINESTAR TECHSTAR GLOVE LARGE ', 'ALPINESTAR TECHSTAR GLOVE LARGE ', 2, 1, 1181, '', 0.00, 4125.00, 0, '2015-07-31', 0, 4125.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1182, 0, 12, 'FASTLANE VENTED SHOE BLACK ANTH 9/42', 'FASTLANE VENTED SHOE BLACK ANTH 9/42', 2, 1, 1182, '', 5531.25, 9735.00, 1, '2015-07-31', 0, 9735.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1183, 0, 12, 'FASTLANE SHOE BLACK 10/43', 'FASTLANE SHOE BLACK 10/43', 2, 1, 1183, '', 5531.25, 9735.00, 1, '2015-07-31', 0, 9735.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1184, 0, 12, 'S-MX 1 BLACK 44/9.5', 'S-MX 1 BLACK 44/9.5', 2, 1, 1184, '', 7687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1185, 0, 12, 'S-MX 2 BLACK 9/43', 'S-MX 2 BLACK 9/43', 2, 1, 1185, '', 8250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1186, 0, 12, 'S-MX 1.1 BLACK 44/9.5', 'S-MX 1.1 BLACK 44/9.5', 2, 1, 1186, '', 6937.50, 11210.00, 0, '2015-07-31', 0, 11210.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1187, 0, 12, 'S-MX 1.1 BLACK 43/9', 'S-MX 1.1 BLACK 43/9', 2, 1, 1187, '', 6937.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1188, 0, 12, 'SMX PLUS WTE.BLK 44/9.5', 'SMX PLUS WTE.BLK 44/9.5', 2, 1, 1188, '', 12656.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1189, 0, 12, 'BONNEVILLE AIR JACKET R.W.BLK - LARGE', 'BONNEVILLE AIR JACKET R.W.BLK - LARGE', 2, 1, 1189, '', 5468.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1190, 0, 12, 'T-DYNO AIR JACKET WHT.BLK - XLARGE', 'T-DYNO AIR JACKET WHT.BLK - XLARGE', 2, 1, 1190, '', 8156.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1191, 0, 12, 'STRICKER AIR PANTS RED.WHT.BLK - MEDIUM', 'STRICKER AIR PANTS RED.WHT.BLK - MEDIUM', 2, 1, 1191, '', 5093.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1192, 0, 12, 'STRICKER AIR PANTS RED.WHT.BLK - LARGE', 'STRICKER AIR PANTS RED.WHT.BLK - LARGE', 2, 1, 1192, '', 5093.75, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1193, 0, 12, 'STRICKER AIR PANTS RED.WHT.BLK - XLARGE', 'STRICKER AIR PANTS RED.WHT.BLK - XLARGE', 2, 1, 1193, '', 5093.75, 8965.00, 0, '2015-07-31', 0, 8965.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1194, 0, 12, 'BIONIC BACK PROTECTOR AIR INSERT BLACK - MEDIUM', 'BIONIC BACK PROTECTOR AIR INSERT BLACK - MEDIUM', 2, 1, 1194, '', 3000.00, 9000.00, 1, '2015-07-31', 0, 9000.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1195, 0, 12, 'BIONIC BACK PROTECTOR AIR WHITE - MEDIUM', 'BIONIC BACK PROTECTOR AIR WHITE - MEDIUM', 2, 1, 1195, '', 4687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1196, 0, 12, 'BIONIC BACK PROTECTOR AIR WHITE - LARGE', 'BIONIC BACK PROTECTOR AIR WHITE - LARGE', 2, 1, 1196, '', 4687.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1197, 0, 12, 'ARCTIC DRYSTAR GLOVES BLACK - LARGE', 'ARCTIC DRYSTAR GLOVES BLACK - LARGE', 2, 1, 1197, '', 3750.00, 6600.00, 1, '2015-07-31', 0, 6600.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1198, 0, 12, 'ARCTIC DRYSTAR GLOVES BLACK - XLARGE', 'ARCTIC DRYSTAR GLOVES BLACK - XLARGE', 2, 1, 1198, '', 3750.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1199, 0, 12, 'THUNDER GLOVES BLACK - XLARGE', 'THUNDER GLOVES BLACK - XLARGE', 2, 1, 1199, '', 3562.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1200, 0, 12, 'SP-1 GLOVES BLACK - LARGE', 'SP-1 GLOVES BLACK - LARGE', 2, 1, 1200, '', 5625.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1201, 0, 12, 'JET ROAD GORETEX GLOVES BLACK - LARGE', 'JET ROAD GORETEX GLOVES BLACK - LARGE', 2, 1, 1201, '', 6562.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1202, 0, 12, 'MUSTANG GLOVES BLACK WHITE - LARGE', 'MUSTANG GLOVES BLACK WHITE - LARGE', 2, 1, 1202, '', 3281.25, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1203, 0, 12, 'MUSTANG GLOVES BLACK WHITE - XLARGE', 'MUSTANG GLOVES BLACK WHITE - XLARGE', 2, 1, 1203, '', 3281.25, 5775.00, 0, '2015-07-31', 0, 5775.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1204, 0, 12, 'SMX-2 AIR CARBON GLOVES BLACK.RED - LARGE', 'SMX-2 AIR CARBON GLOVES BLACK.RED - LARGE', 2, 1, 1204, '', 3000.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1205, 0, 12, 'SMX-2 AIR CARBON GLOVES BLACK RED - XLARGE', 'SMX-2 AIR CARBON GLOVES BLACK RED - XLARGE', 2, 1, 1205, '', 3000.00, 5280.00, 0, '2015-07-31', 0, 5280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1206, 0, 12, 'SMX-2 AIR CARBON GLOVES BLACK GREEN - LARGE', 'SMX-2 AIR CARBON GLOVES BLACK GREEN - LARGE', 2, 1, 1206, '', 3000.00, 5280.00, 1, '2015-07-31', 0, 5280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1207, 0, 12, 'SMX-2 AIR CARBON GLOVES BLACK GREEN - XLARGE', 'SMX-2 AIR CARBON GLOVES BLACK GREEN - XLARGE', 2, 1, 1207, '', 3000.00, 5280.00, 1, '2015-07-31', 0, 5280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1208, 0, 12, 'SMX-2 AIR CARBON GLOVES BLUE WHITE - LARGE', 'SMX-2 AIR CARBON GLOVES BLUE WHITE - LARGE', 2, 1, 1208, '', 3000.00, 5280.00, 1, '2015-07-31', 0, 5280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1209, 0, 12, 'SMX-2 AIR CARBON GLOVES RED WHITE - XLARGE', 'SMX-2 AIR CARBON GLOVES RED WHITE - XLARGE', 2, 1, 1209, '', 3000.00, 5280.00, 1, '2015-07-31', 0, 5280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1210, 0, 12, 'SMX CARBON GLOVE BLACK - M ', 'SMX CARBON GLOVE BLACK - M ', 2, 1, 1210, '', 0.00, 3960.00, 1, '2015-07-31', 0, 3960.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1211, 0, 12, 'SMX CARBON GLOVE BLACK - L', 'SMX CARBON GLOVE BLACK - L', 2, 1, 1211, '', 0.00, 3960.00, 0, '2015-07-31', 0, 3960.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1212, 0, 12, 'GP PLUS GLOVES BLK.WHT XLARGE', 'GP PLUS GLOVES BLK.WHT XLARGE', 2, 1, 1212, '', 7500.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1213, 0, 12, 'SCHEME KEVLAR GLOVES B.W.Y.FLUO - LARGE', 'SCHEME KEVLAR GLOVES B.W.Y.FLUO - LARGE', 2, 1, 1213, '', 2250.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1214, 0, 12, 'SCHEME KEVLAR GLOVES B.W.Y.FLUO - XLARGE', 'SCHEME KEVLAR GLOVES B.W.Y.FLUO - XLARGE', 2, 1, 1214, '', 2250.00, 3960.00, 0, '2015-07-31', 0, 3960.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1216, 0, 20, 'HELMET CL PRIMO KYT EMBLEM NEON ORANGE/G.METAL #2 XL', 'HELMET CL PRIMO KYT EMBLEM NEON ORANGE/G.METAL #2 XL', 2, 1, 1216, '', 0.00, 4150.00, 0, '2015-07-31', 0, 4150.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1217, 0, 21, 'BELL HELMET SX-1 SWITCH ORANGE L ', 'BELL HELMET SX-1 SWITCH ORANGE L ', 2, 1, 1217, '', 3213.00, 5555.00, 0, '2015-07-31', 0, 5555.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1218, 0, 21, 'BELL HELMET SX-1 APEX XXL ', 'BELL HELMET SX-1 APEX XXL ', 2, 1, 1218, '', 3213.00, 5555.00, 1, '2015-07-31', 0, 5555.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1219, 0, 31, 'SPYDER HELMET RECON GD 694 LARGE', 'SPYDER HELMET RECON GD 694 LARGE', 2, 1, 1219, '', 2246.25, 3460.00, 1, '2015-07-31', 0, 3460.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1220, 0, 31, 'SPYDER HELMET SIERRA GD 362 LARGE ', 'SPYDER HELMET SIERRA GD 362 LARGE ', 2, 1, 1220, '', 2396.25, 3700.00, 2, '2015-07-31', 0, 3700.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1221, 0, 31, 'SPYDER RECON P 100 L SH. WHITE', 'SPYDER RECON P 100 L SH. WHITE', 2, 1, 1221, '', 0.00, 2655.00, 2, '2015-07-31', 0, 2655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1222, 0, 31, 'SPYDER HELMET SIERRA DV 900 MEDIUM ', 'SPYDER HELMET SIERRA DV 900 MEDIUM ', 2, 1, 1222, '', 2396.25, 3700.00, 1, '2015-07-31', 0, 3700.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1223, 0, 31, 'SPYDER HELMET RECON G 384 MEDIUM ', 'SPYDER HELMET RECON G 384 MEDIUM ', 2, 1, 1223, '', 2396.25, 2885.00, 1, '2015-07-31', 0, 2885.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1224, 0, 31, 'SPYDER HELMET PHOENIX 165 MEDIUM ', 'SPYDER HELMET PHOENIX 165 MEDIUM ', 2, 1, 1224, '', 1721.25, 2655.00, 1, '2015-07-31', 0, 2655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1225, 0, 31, 'SPYDER HELMET BOURNE 993 LARGE ', 'SPYDER HELMET BOURNE 993 LARGE ', 2, 1, 1225, '', 1496.25, 2305.00, 1, '2015-07-31', 0, 2305.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1226, 0, 31, 'SPYDER HELMET RECON G 384 LARGE ', 'SPYDER HELMET RECON G 384 LARGE ', 2, 1, 1226, '', 1871.25, 2885.00, 1, '2015-07-31', 0, 2885.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1227, 0, 31, 'SPYDER RECON P 300 M SH. BLK ', 'SPYDER RECON P 300 M SH. BLK ', 2, 1, 1227, '', 2295.00, 2655.00, 0, '2015-07-31', 0, 2655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1228, 0, 31, 'SPYDER RECON P 100 M SH WHITE - 12038462', 'SPYDER RECON P 100 M SH WHITE - 12038462', 2, 1, 1228, '', 2295.00, 2655.00, 1, '2015-07-31', 0, 2655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1229, 0, 31, 'SPYDER RECON P 100 XL SH WHITE ', 'SPYDER RECON P 100 XL SH WHITE ', 2, 1, 1229, '', 2295.00, 2655.00, 0, '2015-07-31', 0, 2655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1230, 0, 31, 'SPYDER RECON GD 361 L BLK/RED ', 'SPYDER RECON GD 361 L BLK/RED ', 2, 1, 1230, '', 3150.00, 3465.00, 0, '2015-07-31', 0, 3465.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1231, 0, 31, 'SPYDER SIERRA GD 362 XL RED/BLK', 'SPYDER SIERRA GD 362 XL RED/BLK', 2, 1, 1231, '', 3150.00, 3700.00, 0, '2015-07-31', 0, 3700.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1232, 0, 21, 'BELL HELMET QUALIFIER SOLID MATTE BLACK - LARGE', 'BELL HELMET QUALIFIER SOLID MATTE BLACK - LARGE', 2, 1, 1232, '', 0.00, 4830.00, 1, '2015-07-31', 0, 4830.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1233, 0, 21, 'BELL HELMET QUALIFIER SOLID MATTE BLACK - XLARGE', 'BELL HELMET QUALIFIER SOLID MATTE BLACK - XLARGE', 2, 1, 1233, '', 0.00, 4830.00, 0, '2015-07-31', 0, 4830.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1234, 0, 21, 'BELL HELMET QUALIFIER SILVER - XL ', 'BELL HELMET QUALIFIER SILVER - XL ', 2, 1, 1234, '', 0.00, 4830.00, 0, '2015-07-31', 0, 4830.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1235, 0, 20, 'CL PRIMO KYT EMBLEM NEON ORANGE/GUN METAL #1 - M', 'CL PRIMO KYT EMBLEM NEON ORANGE/GUN METAL #1 - M', 2, 1, 1235, '', 0.00, 4150.00, 1, '2015-07-31', 0, 4150.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1236, 0, 20, 'KYT VENDETA 2RACE - NEON ORANGE/GUNMETAL/ORANGE - XL', 'KYT VENDETA 2RACE - NEON ORANGE/GUNMETAL/ORANGE - XL', 2, 1, 1236, '', 0.00, 4750.00, 1, '2015-07-31', 0, 4750.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1237, 0, 20, 'KYT HELMET RC SEVEN #5 BLK/RED/ORNGE GUN METAL (M)', 'KYT HELMET RC SEVEN #5 BLK/RED/ORNGE GUN METAL (M)', 2, 1, 1237, '', 0.00, 3280.00, 1, '2015-07-31', 0, 3280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1238, 0, 20, 'KYT HELMET RC SEVEN #5 BLK/RED/ORNGE GUN METAL (L)', 'KYT HELMET RC SEVEN #5 BLK/RED/ORNGE GUN METAL (L)', 2, 1, 1238, '', 2128.00, 3340.00, 0, '2015-07-31', 0, 3340.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1239, 0, 20, 'KYT GALAXY SLIDE 2 DOUBLE VISOR - WHT/RED-M', 'KYT GALAXY SLIDE 2 DOUBLE VISOR - WHT/RED-M', 2, 1, 1239, '', 0.00, 3020.00, 0, '2015-07-31', 0, 3020.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1240, 0, 20, 'KYT HELMET RC SEVEN #5 BLK/RED/ORNGE GUN METAL (XL)', 'KYT HELMET RC SEVEN #5 BLK/RED/ORNGE GUN METAL (XL)', 2, 1, 1240, '', 0.00, 3280.00, 0, '2015-07-31', 0, 3280.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1241, 0, 20, 'KYT ADVENTURE LOGO DOUBLE VISOR - L ', 'KYT ADVENTURE LOGO DOUBLE VISOR - L ', 2, 1, 1241, '', 0.00, 5055.00, 0, '2015-07-31', 0, 5055.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1242, 0, 46, 'ARAI HELMET TOUR CROSS 3-AURORA /BLACK ', 'ARAI HELMET TOUR CROSS 3-AURORA /BLACK ', 2, 1, 1242, '', 0.00, 39050.00, 1, '2015-07-31', 0, 39050.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1243, 0, 48, 'HELMET SUOMY MR. JUMP LARGE -KILLER LOOP ', 'HELMET SUOMY MR. JUMP LARGE -KILLER LOOP ', 2, 1, 1243, '', 0.00, 18500.00, 1, '2015-07-31', 0, 18500.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1248, 0, 13, 'TESTASTRETTA III DUCATI - 8.5/42.5 ', 'TESTASTRETTA III DUCATI - 8.5/42.5 ', 2, 12, 1248, '', 3125.00, 5270.00, 1, '2015-07-31', 0, 5270.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1250, 0, 9, 'MOTORAZZO STREET RACER DUCATI - 8/42', 'MOTORAZZO STREET RACER DUCATI - 8/42', 2, 12, 1250, '', 2678.57, 4917.00, 1, '2015-07-31', 0, 4917.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1251, 0, 9, 'MOTORAZZO STREET RACER DUCATI - 9/43', 'MOTORAZZO STREET RACER DUCATI - 9/43', 2, 12, 1251, '', 2678.57, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1252, 0, 9, '65 CC LO DUCATI - 8.5/42.5 WWBlack', '65 CC LO DUCATI - 8.5/42.5 WWBlack', 2, 12, 1252, '', 1964.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1253, 0, 9, '65 CC LO DUCATI - 9.5/44 WWBlack', '65 CC LO DUCATI - 9.5/44 WWBlack', 2, 12, 1253, '', 1964.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1254, 0, 9, '65 CC LO DUCATI - 9/43 WWBlack', '65 CC LO DUCATI - 9/43 WWBlack', 2, 12, 1254, '', 1964.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1255, 0, 9, '65 CC LO DUCATI - 10/44.5 WWBlack', '65 CC LO DUCATI - 10/44.5 WWBlack', 2, 12, 1255, '', 1964.29, 3509.00, 1, '2015-07-31', 0, 3509.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1256, 0, 9, '65 CC DUCATI - 8/42 Gamusa', '65 CC DUCATI - 8/42 Gamusa', 2, 12, 1256, '', 2232.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1257, 0, 9, '65 CC DUCATI - 8.5/42.5 Gamusa', '65 CC DUCATI - 8.5/42.5 Gamusa', 2, 12, 1257, '', 2232.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1258, 0, 9, '65 CC DUCATI - 9/43 Gamusa', '65 CC DUCATI - 9/43 Gamusa', 2, 12, 1258, '', 2232.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1259, 0, 9, '65 CC DUCATI - 10/44.5 Gamusa', '65 CC DUCATI - 10/44.5 Gamusa', 2, 12, 1259, '', 2232.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1260, 0, 9, 'HYPERMOTARD LOW DUCATI - 7/40.5', 'HYPERMOTARD LOW DUCATI - 7/40.5', 2, 12, 1260, '', 2946.43, 4950.00, 1, '2015-07-31', 0, 4950.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1261, 0, 9, 'HYPERMOTARD LOW DUCATI - 7.5/41', 'HYPERMOTARD LOW DUCATI - 7.5/41', 2, 12, 1261, '', 2946.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1262, 0, 9, 'HYPERMOTARD LOW DUCATI - 8.5/42.5', 'HYPERMOTARD LOW DUCATI - 8.5/42.5', 2, 12, 1262, '', 2946.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1263, 0, 9, 'HYPERMOTARD LOW DUCATI - 9/43', 'HYPERMOTARD LOW DUCATI - 9/43', 2, 12, 1263, '', 2946.43, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1264, 0, 9, 'DUCATI ONE UPS TEE - MEDIUM', 'DUCATI ONE UPS TEE - MEDIUM', 2, 1, 1264, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1265, 0, 9, 'DUCATI ONE UPS TEE - LARGE', 'DUCATI ONE UPS TEE - LARGE', 2, 1, 1265, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1266, 0, 9, 'DUCATI ONE UPS TEE - XLARGE', 'DUCATI ONE UPS TEE - XLARGE', 2, 1, 1266, '', 1205.36, 1620.00, 1, '2015-07-31', 0, 1620.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1267, 0, 9, 'DUCATI TRACK JACKET - SMALL', 'DUCATI TRACK JACKET - SMALL', 2, 1, 1267, '', 2187.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1268, 0, 9, 'DUCATI TRACK JACKET - MEDIUM', 'DUCATI TRACK JACKET - MEDIUM', 2, 1, 1268, '', 2187.50, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1269, 0, 9, 'DUCATI GRAPHIC TEE - SMALL', 'DUCATI GRAPHIC TEE - SMALL', 2, 1, 1269, '', 1116.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1270, 0, 9, 'DUCATI GRAPHIC TEE - MEDIUM', 'DUCATI GRAPHIC TEE - MEDIUM', 2, 1, 1270, '', 1116.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1271, 0, 9, 'DUCATI GRAPHIC TEE - XLARGE', 'DUCATI GRAPHIC TEE - XLARGE', 2, 1, 1271, '', 1116.07, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1272, 0, 9, 'DUCATI ONE UPS TEE V2 - SMALL - 1 faded', 'DUCATI ONE UPS TEE V2 - SMALL - 1 faded', 2, 1, 1272, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1273, 0, 9, 'DUCATI ONE UPS TEE V2 - MEDIUM', 'DUCATI ONE UPS TEE V2 - MEDIUM', 2, 1, 1273, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1274, 0, 9, 'DUCATI ONE UPS TEE V2 - LARGE', 'DUCATI ONE UPS TEE V2 - LARGE', 2, 1, 1274, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1275, 0, 9, 'DUCATI ONE UPS TEE V2 - XLARGE', 'DUCATI ONE UPS TEE V2 - XLARGE', 2, 1, 1275, '', 1205.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1289, 0, 14, 'PIRELLI TYRE DIABLO STRADA 120/60-17', 'PIRELLI TYRE DIABLO STRADA 120/60-17', 5, 1, 1289, '', 3357.14, 6842.00, 1, '2015-07-31', 0, 6842.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1290, 0, 14, 'PIRELLI DIABLO ROSSO CORSA 120/70-17', 'PIRELLI DIABLO ROSSO CORSA 120/70-17', 5, 1, 1290, '', 6865.51, 10164.00, 1, '2015-07-31', 0, 10164.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1291, 0, 14, 'PIRELLI DIABLO ROSSO CORSA 180/55-17', 'PIRELLI DIABLO ROSSO CORSA 180/55-17', 5, 1, 1291, '', 9142.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1292, 0, 14, 'PIRELLI DIABLO ROSSO CORSA 190/55-17', 'PIRELLI DIABLO ROSSO CORSA 190/55-17', 5, 1, 1292, '', 7212.05, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1293, 0, 14, 'PIRELLI SCORPION MX 110/90-19', 'PIRELLI SCORPION MX 110/90-19', 5, 1, 1293, '', 3392.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1294, 0, 14, 'PIRELLI SC MX J 70/100-19', 'PIRELLI SC MX J 70/100-19', 5, 1, 1294, '', 2107.14, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1295, 0, 14, 'PIRELLI SCORPION MX 60/100-14', 'PIRELLI SCORPION MX 60/100-14', 5, 1, 1295, '', 1392.86, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1296, 0, 14, 'PIRELLI SCORPION MX 60/100-12', 'PIRELLI SCORPION MX 60/100-12', 5, 1, 1296, '', 1214.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1297, 0, 14, 'PIRELLI SCORPION MX 2.75-10', 'PIRELLI SCORPION MX 2.75-10', 5, 1, 1297, '', 1200.00, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1298, 0, 14, 'PIRELLI DIABLO ROSSO II 240/45-17', 'PIRELLI DIABLO ROSSO II 240/45-17', 5, 1, 1298, '', 11285.72, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1299, 0, 14, 'PIRELLI DIABLO ROSSO II 110/70-17', 'PIRELLI DIABLO ROSSO II 110/70-17', 5, 1, 1299, '', 4339.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1300, 0, 14, 'PIRELLI DIABLO ROSSO II 150/60-17', 'PIRELLI DIABLO ROSSO II 150/60-17', 5, 1, 1300, '', 4339.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1301, 0, 14, 'PIRELLI MT 60 R CORSA 160/60-17', 'PIRELLI MT 60 R CORSA 160/60-17', 5, 1, 1301, '', 0.00, 12345.00, 1, '2015-07-31', 0, 12345.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1302, 0, 14, 'PIRELLI MT 60 R CORSA 120/70-17', 'PIRELLI MT 60 R CORSA 120/70-17', 5, 1, 1302, '', 0.00, 9320.00, 1, '2015-07-31', 0, 9320.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1303, 0, 14, 'PIRELLI ANGEL GT - 160/60-17', 'PIRELLI ANGEL GT - 160/60-17', 5, 1, 1303, '', 0.00, 13070.00, 1, '2015-07-31', 0, 13070.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1304, 0, 14, 'PIRELLI ANGEL ST - 120/60-17', 'PIRELLI ANGEL ST - 120/60-17', 5, 1, 1304, '', 0.00, 9317.00, 1, '2015-07-31', 0, 9317.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1305, 0, 14, 'PIRELLI ANGEL ST - 120/70-17', 'PIRELLI ANGEL ST - 120/70-17', 5, 1, 1305, '', 5604.91, 8954.00, 1, '2015-07-31', 0, 8954.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1306, 0, 14, 'PIRELLI ANGEL ST - 180/55-17', 'PIRELLI ANGEL ST - 180/55-17', 5, 1, 1306, '', 5604.91, 12584.00, 0, '2015-07-31', 0, 12584.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1316, 0, 15, 'METZELER SPORTEC M3 120/70-17', 'METZELER SPORTEC M3 120/70-17', 5, 1, 1316, '', 5303.57, 7623.00, 1, '2015-07-31', 0, 7623.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1317, 0, 15, 'METZELER SPORTEC M3 180/55-17', 'METZELER SPORTEC M3 180/55-17', 5, 1, 1317, '', 6291.67, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1318, 0, 15, 'METZELER SPORTEC M3 190/55-17', 'METZELER SPORTEC M3 190/55-17', 5, 1, 1318, '', 6291.67, 10890.00, 0, '2015-07-31', 0, 10890.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1334, 0, 16, 'MOTOBATT MBT12B4 (YT12B-BS)', 'MOTOBATT MBT12B4 (YT12B-BS)', 6, 1, 1334, '', 2883.93, 5855.00, 2, '2015-07-31', 0, 5855.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1335, 0, 16, 'MOTOBATT MBTX9U', 'MOTOBATT MBTX9U', 6, 1, 1335, '', 2883.93, 5855.00, 0, '2015-07-31', 0, 5855.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1336, 0, 16, 'MOTOBATT MBTZ10S (YTZ10S)', 'MOTOBATT MBTZ10S (YTZ10S)', 6, 1, 1336, '', 2428.57, 4195.00, 0, '2015-07-31', 0, 4195.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1339, 0, 17, 'YUASA YTX4L-BS', 'YUASA YTX4L-BS', 6, 1, 1339, '', 0.00, 3115.00, 0, '2015-07-31', 0, 3115.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1340, 0, 17, 'YUASA YTX7L-BS', 'YUASA YTX7L-BS', 6, 1, 1340, '', 0.00, 6437.20, 1, '2015-07-31', 0, 6437.20, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1345, 0, 33, 'RR MOTORCYCLE BATTERY - JT9A-BS', 'RR MOTORCYCLE BATTERY - JT9A-BS', 6, 1, 1345, '', 0.00, 3115.00, 1, '2015-07-31', 0, 3115.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1351, 0, 18, 'ADVANCE - 4TULTRA / 10W40', 'ADVANCE - 4TULTRA / 10W40', 7, 4, 1351, '', 328.94, 540.00, 42, '2015-07-31', 0, 540.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1353, 0, 19, 'CASTROL POWER 1 4T - 15W-40', 'CASTROL POWER 1 4T - 15W-40', 7, 4, 1353, '', 191.07, 320.00, 0, '2015-07-31', 0, 320.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1354, 0, 19, 'CASTROL POWER 1 10W-50 FULLY SYNTHETIC', 'CASTROL POWER 1 10W-50 FULLY SYNTHETIC', 7, 4, 1354, '', 378.57, 583.00, 22, '2015-07-31', 0, 583.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1355, 0, 19, 'CASTROL CRB TURBO 15W-40', 'CASTROL CRB TURBO 15W-40', 7, 4, 1355, '', 169.64, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1356, 0, 19, 'CASTROL GTX DIESEL 15W-40', 'CASTROL GTX DIESEL 15W-40', 7, 4, 1356, '', 180.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1357, 0, 19, 'CASTROL GTX GASOLINE 20W-40', 'CASTROL GTX GASOLINE 20W-40', 7, 4, 1357, '', 183.93, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1358, 0, 19, 'CASTROL MAGNATEC 10w-40', 'CASTROL MAGNATEC 10w-40', 7, 4, 1358, '', 263.39, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1359, 0, 19, 'CASTROL MAGNATEC by 4LITER', 'CASTROL MAGNATEC by 4LITER', 7, 4, 1359, '', 980.36, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1360, 0, 19, 'CASTROL RADICOOL COOLANT CONCENTRATE', 'CASTROL RADICOOL COOLANT CONCENTRATE', 7, 4, 1360, '', 260.72, 468.00, 14, '2015-07-31', 0, 468.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1361, 0, 19, 'CASTROL 4T-1L MINERAL 20W-40', 'CASTROL 4T-1L MINERAL 20W-40', 7, 4, 1361, '', 139.29, 242.00, 2, '2015-07-31', 0, 242.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1362, 0, 19, 'CASTROL BRAKE FLUID DOT 4 - 500ML', 'CASTROL BRAKE FLUID DOT 4 - 500ML', 7, 1, 1362, '', 111.61, 182.00, 12, '2015-07-31', 0, 182.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1364, 0, 26, 'MOTOREX CHAIN LUBE 500ML', 'MOTOREX CHAIN LUBE 500ML', 7, 4, 1364, '', 466.07, 805.00, 12, '2015-07-31', 0, 805.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'NDC-TMP', 4),
	(1365, 0, 26, 'MOTOREX CHAIN LUBE 56ML', 'MOTOREX CHAIN LUBE 56ML', 7, 4, 1365, '', 205.36, 358.00, 0, '2015-07-31', 0, 358.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1366, 0, 26, 'MOTOREX BRAKE FLUID DOT 5.1', 'MOTOREX BRAKE FLUID DOT 5.1', 7, 4, 1366, '', 317.41, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1367, 0, 26, 'MOTOREX BRAKE FLUID DOT 4 - 250g', 'MOTOREX BRAKE FLUID DOT 4 - 250g', 7, 6, 1367, '', 289.29, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1368, 0, 26, 'MOTOREX FORK OIL SEMI 10W-30', 'MOTOREX FORK OIL SEMI 10W-30', 7, 4, 1368, '', 466.07, 809.00, 8, '2015-07-31', 0, 809.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1369, 0, 26, 'MOTOREX FORK OIL RACING 15W', 'MOTOREX FORK OIL RACING 15W', 7, 4, 1369, '', 498.86, 864.00, 14, '2015-07-31', 0, 864.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1370, 0, 26, 'MOTOREX POWER FULLY SYNTHETIC 10W-50', 'MOTOREX POWER FULLY SYNTHETIC 10W-50', 7, 4, 1370, '', 554.46, 960.00, 44, '2015-07-31', 0, 960.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1371, 0, 26, 'MOTOREX FORMULA SEMI SYNTH 15W-50', 'MOTOREX FORMULA SEMI SYNTH 15W-50', 7, 4, 1371, '', 377.68, 655.00, 37, '2015-07-31', 0, 655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1372, 0, 26, 'MOTOREX CARBURATOR CLEANER 500ML', 'MOTOREX CARBURATOR CLEANER 500ML', 7, 4, 1372, '', 385.71, 670.00, 9, '2015-07-31', 0, 670.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'NDC-TMP', 4),
	(1373, 0, 26, 'MOTOREX KTM RACING OIL', 'MOTOREX KTM RACING OIL', 7, 4, 1373, '', 795.54, 0.00, 0, '2015-07-31', 0, 0.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1374, 0, 26, 'MOTOREX 2T XPOWER FULLY SYNTHETIC', 'MOTOREX 2T XPOWER FULLY SYNTHETIC', 7, 4, 1374, '', 602.68, 1039.00, 4, '2015-07-31', 0, 1039.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1375, 0, 26, 'MOTOREX COOLANT', 'MOTOREX COOLANT', 7, 4, 1375, '', 337.50, 650.00, 10, '2015-07-31', 0, 650.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'A1', 0),
	(1376, 0, 26, 'MOTOREX AIR FILTER CLEANER - 1LTR', 'MOTOREX AIR FILTER CLEANER - 1LTR', 7, 4, 1376, '', 377.68, 655.00, 1, '2015-07-31', 0, 655.00, '2015-07-31', 'BRANDNEW', 3, '', '', 'SHOWROOM', 0),
	(1377, 0, 26, 'MOTOREX SCOOTER MOTOR OIL 10W-40', 'MOTOREX SCOOTER MOTOR OIL 10W-40', 7, 4, 1377, NULL, 0.00, 670.00, 0, '2015-09-19', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1378, 0, 1, 'FOOT BRAKE LEVER KIT ', 'FOOT BRAKE LEVER KIT ', 1, 1, 1378, NULL, 0.00, 2310.00, 0, '2015-09-19', NULL, NULL, NULL, 'BRAND NEW', 0, '90113050133', NULL, 'NDC-TMP', 4),
	(1379, 0, 8, 'NORMINRING DEALER PLATE', 'NORMINRING DEALER PLATE', 1, 1, 1379, NULL, 0.00, 150.00, 0, '2015-09-19', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1380, 0, 1, 'FOOT BRAKE LEVER KIT ', 'FOOT BRAKE LEVER KIT ', 1, 1, 1380, NULL, 0.00, 2310.00, 0, '2015-09-19', NULL, NULL, NULL, 'BRAND NEW', 0, '90113050133', NULL, 'NDC-TMP', 4),
	(1381, 0, 8, 'NORMINRING DEALER PLATE', 'NORMINRING DEALER PLATE', 1, 1, 1381, NULL, 0.00, 150.00, 0, '2015-09-19', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1382, 0, 7, 'SET OF THERMOFORMED SIDE PANNIERS-ROADR', 'SET OF THERMOFORMED SIDE PANNIERS-ROADR', 1, 9, 1382, NULL, 0.00, 52175.00, 0, '2015-09-19', NULL, NULL, NULL, 'BRAND NEW', 0, '96780411A', NULL, 'NDC-TMP', 4),
	(1383, 0, 18, 'Shell Oil', 'Shell Spirax S 90', 7, 1, 1383, NULL, 0.00, 290.00, 0, '2015-10-01', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1384, 0, 1, 'KTM CDO T-shirts white small', 'KTM CDO T-shirts white small', 2, 1, 1384, NULL, 0.00, 550.00, 0, '2015-10-01', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1385, 0, 1, 'KTM CDO T-shirts White Medium', 'KTM CDO T-shirts White Medium', 2, 1, 1385, NULL, 0.00, 550.00, 0, '2015-10-01', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1386, 0, 0, 'KTM CDO T-shirts White Medium', 'KTM CDO T-shirts White Medium', 2, 1, 1386, NULL, 0.00, 550.00, 0, '2015-10-01', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1387, 0, 1, 'Side stand Switch', 'Side stand Switch for KTM Duke 200', 1, 1, 1387, NULL, 0.00, 900.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '90111045000', NULL, 'NDC-TMP', 4),
	(1388, 6, 1, 'Screw F. Side Stand', 'Screw F. Side Stand', 1, 1, 1388, NULL, 0.00, 125.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '90103027000', NULL, 'NDC-TMP', 4),
	(1389, 6, 1, 'side stand spring', 'side stand spring - 90603024000', 1, 1, 1389, NULL, 0.00, 550.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '90603024000', NULL, 'NDC-TMP', 4),
	(1390, 0, 8, 'VS1', 'VS 1 250 ml', 4, 1, 1390, NULL, 0.00, 175.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1391, 0, 8, 'WD40', 'WD40', 4, 5, 1391, NULL, 0.00, 145.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1392, 0, 0, 'Electrical Sudering Iron', 'Electrical Sudering Iron', 4, 1, 1392, NULL, 0.00, 160.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1393, 0, 8, 'Steel Brush Plasic', 'Steel Brush Plasic', 4, 1, 1393, NULL, 0.00, 30.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1394, 0, 8, 'Wire Brush', 'Wire Brush', 4, 1, 1394, NULL, 0.00, 27.00, 0, '2015-10-05', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1395, 0, 8, 'Socket Long L 1/2', 'Socket Long L 1/2', 4, 1, 1395, NULL, 0.00, 0.00, 0, '2015-10-09', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1396, 0, 8, 'Threadlocker Med. Strength BL', 'Threadlocker Med. Strength BL', 4, 1, 1396, NULL, 0.00, 0.00, 0, '2015-10-09', NULL, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 4),
	(1397, 0, 1, 'MAGNET HOLDER', 'MAGNET HOLDER ', 1, 1, 1397, NULL, 0.00, 250.00, 0, '2015-10-09', 0, NULL, '2015-11-13', 'BRAND NEW', 3, '90103029000', '_', 'NDC-TMP', 4),
	(1398, 0, 1, 'Sling Bag Ktm Messenger', 'Sling Bag Ktm Messenger', 2, 2, 1398, NULL, 0.00, NULL, 1080, '2015-10-17', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1399, 14, 1, 'SLING BAG KTM MESSENGER', 'SLING BAG KTM MESSENGER', 2, 2, 1399, NULL, 625.00, 1080.00, 1080, '2015-10-19', 12, 0.00, '2015-10-19', 'BRAND NEW', 0, '023692', NULL, 'SHOW ROOM', 5),
	(1400, 14, 1, 'TRAIL BACK PACK KTM W/ BLADDER', 'TRAIL BACK PACK KTM W/ BLADDER', 2, 10, 1400, NULL, 800.00, 1390.00, 1390, '2015-10-19', 12, 0.00, '2015-10-19', 'BRAND NEW', 0, '023889', NULL, 'SHOW ROOM', 5),
	(1401, 5, 1, 'ACERBIS JACKET ORANGE XL', 'ACERBIS JACKET ORANGE XL', 2, 1, 1401, NULL, 0.00, NULL, 5555, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '0017105.010068', NULL, 'SHOW ROOM', 5),
	(1402, 5, 1, 'ACERBIS JACKET ORANGE MEDIUM', 'ACERBIS JACKET ORANGE MEDIUM', 2, 1, 1402, NULL, 0.00, NULL, 5555, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '0017105.010064', NULL, 'SHOW ROOM', 5),
	(1403, 5, 1, 'ACERBIS JACKET ORANGE LARGE', 'ACERBIS JACKET ORANGE LARGE', 2, 1, 1403, NULL, 0.00, NULL, 5555, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '0017105.010066', NULL, 'SHOW ROOM', 5),
	(1404, 5, 1, 'ACERBIS JACKET BLACK MEDIUM', 'ACERBIS JACKET BLACK MEDIUM', 2, 1, 1404, NULL, 0.00, NULL, 5555, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '0017105.090.064', NULL, 'SHOW ROOM', 5),
	(1405, 5, 1, 'ACERBIS JACKET BLACK LARGE', 'ACERBIS JACKET BLACK LARGE', 2, 1, 1405, NULL, 0.00, NULL, 5555, '2015-10-19', 112, NULL, NULL, 'BRAND NEW', 0, '0017105.090.066', NULL, 'SHOW ROOM', 0),
	(1406, 7, 1, 'ROLL OVER SENSOR', 'ROLL OVER SENSOR', 1, 1, 1406, NULL, 0.00, NULL, 600, '2015-10-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1407, 7, 1, 'ITALJET RED/WHITE', 'ITALJET RED/WHITE', 2, 2, 1407, NULL, 0.00, NULL, 115000, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1408, 12, 1, 'KAWASAKI VERSYS 1000 LIME GREEN', 'KAWASAKI VERSYS 1000 LIME GREEN', 2, 2, 1408, NULL, 0.00, NULL, 650000, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1409, 7, 0, 'KTM RC200 NON-ABS BLACK 2015', 'KTM RC200 NON-ABS BLACK 2015', 2, 2, 1409, NULL, 0.00, NULL, 199000, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'STOCK ROOM', 0),
	(1410, 12, 1, 'KAWASAKI VERSYS 1000 LIME GREEN', 'KAWASAKI VERSYS 1000 LIME GREEN', 2, 2, 1410, NULL, 0.00, NULL, 650000, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1411, 7, 1, 'ITALJET RED/WHITE 2015', 'ITALJET RED/WHITE 2015', 2, 2, 1411, NULL, 0.00, NULL, 115000, '2015-10-19', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1412, 0, 42, 'Italjet Formula', 'Italjet Formula 125 red/white', 3, 3, 1412, NULL, 0.00, NULL, 115000, '2015-10-20', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 0),
	(1413, 0, 30, 'Kawasaki Versys 1000', 'Kawasaki Versys 1000 - Green', 3, 3, 1413, NULL, 0.00, NULL, 650000, '2015-10-20', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'NDC-TMP', 0),
	(1414, 7, 42, 'Italjet Red/White 2015', 'Italjet Red/White 2015', 3, 3, 1414, NULL, 0.00, NULL, 115000, '2015-10-20', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1415, 12, 30, 'Kawasaki Versys 1000 Lime Green 2015', 'Kawasaki Versys 1000 Lime Green 2015', 3, 3, 1415, NULL, 0.00, NULL, 650000, '2015-10-20', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1416, 7, 1, 'Ktm RC 200 Non-abs Black 2015', 'Ktm RC 200 Non-abs Black 2015', 3, 3, 1416, NULL, 0.00, NULL, 199000, '2015-10-20', 12, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1417, 0, 8, 'NDC Trailer ', 'NDC Trailer', 4, 3, 1417, NULL, 0.00, NULL, 75000, '2015-11-03', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1418, 6, 1, 'Speedometer Sensor ', 'Speedometer Sensor ', 1, 1, 1418, NULL, 0.00, NULL, 2750, '2015-11-11', 112, NULL, NULL, 'BRAND NEW', 0, '90114068000', NULL, 'SHOW ROOM', 5),
	(1419, 6, 1, 'Shift Shaft Cpl ', 'Shift Shaft Cpl ', 1, 3, 1419, NULL, 0.00, NULL, 1870, '2015-11-11', 112, NULL, NULL, 'BRAND NEW', 0, '90134005033', NULL, 'SHOW ROOM', 5),
	(1420, 6, 1, 'Seal Ring 13x22x5.5', 'Seal Ring 13x22x5.5', 1, 1, 1420, NULL, 0.00, NULL, 110, '2015-11-11', 112, NULL, NULL, 'BRAND NEW', 0, '90130003004', NULL, 'SHOW ROOM', 5),
	(1421, 7, 1, 'Gasket Clutch Cover ', 'Gasket Clutch Cover ', 1, 1, 1421, NULL, 0.00, NULL, 620, '2015-11-11', 112, NULL, NULL, 'BRAND NEW', 0, '9013002700', NULL, 'SHOW ROOM', 5),
	(1422, 7, 1, 'KTM RC 200 NON-ABS BLACK 2015', 'KTM RC 200 NON-ABS BLACK 2015', 3, 3, 1422, NULL, 0.00, NULL, 199000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SATELLITE PI', 6),
	(1423, 7, 1, 'KTM RC 200 NON-ABS BLACK 2015', 'KTM RC 200 NON-ABS BLACK 2015', 3, 3, 1423, NULL, 0.00, NULL, 199000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SATELLITE PI', 6),
	(1424, 7, 1, 'KTM DUKE 200 NON-ABS ORANGE 2014', 'KTM DUKE 200 NON-ABS ORANGE 2014', 3, 3, 1424, NULL, 0.00, NULL, 169000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SATELLITE PI', 6),
	(1425, 7, 1, 'KTM DUKE 200 NON-ABS ORANGE 2014', 'KTM DUKE 200 NON-ABS ORANGE 2014', 3, 3, 1425, NULL, 0.00, NULL, 169000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1426, 7, 1, 'KTM DUKE 200 NON-ABS WHITE 2014', 'KTM DUKE 200 NON-ABS WHITE 2014', 3, 3, 1426, NULL, 0.00, NULL, 169000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1427, 7, 1, 'KTM RC 200 NON-ABS BLACK 2015', 'KTM RC 200 NON-ABS BLACK 2015', 3, 3, 1427, NULL, 0.00, NULL, 199000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1428, 7, 1, 'KTM RC 390 ABS WHITE 2015', 'KTM RC 390 ABS WHITE 2015', 3, 3, 1428, NULL, 0.00, NULL, 399000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1429, 0, 8, 'NDC TRAILER ', 'NDC TRAILER ', 4, 3, 1429, NULL, 0.00, NULL, 75000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1430, 0, 0, 'NDC TRAILER ', 'NDC TRAILER', 4, 3, 1430, NULL, 0.00, NULL, 75000, '2015-11-19', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1431, 3, 0, 'Motorex Chaine Lube 500ml', 'Motorex Chaine Lube 500ml', 7, 15, 1431, NULL, 0.00, NULL, 805, '2015-11-23', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'STOCK ROOM', 8),
	(1432, 3, 26, 'Motorex Carburator Cleaner 500ml', 'Motorex Carburator Cleaner 500ml', 7, 15, 1432, NULL, 0.00, NULL, 670, '2015-11-23', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'STOCK ROOM', 8),
	(1433, 14, 1, 'Ktm Radiator Grill Duke 200 Orange  ', 'Ktm Radiator Grill Duke 200 Orange  ', 1, 1, 1433, NULL, 0.00, NULL, 2420, '2015-11-23', 112, NULL, NULL, 'BRAND NEW', 0, '021990', NULL, 'SHOW ROOM', 5),
	(1434, 0, 1, 'Ktm CDO Tshirt White - Large ', 'Ktm CDO Tshirt White - Large ', 2, 1, 1434, NULL, 0.00, NULL, 550, '2015-11-23', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1435, 1, 21, 'Bell Helmet Custom 500 Headcase Cue Ball - L', 'Bell Helmet Custom 500 Headcase Cue Ball - L', 2, 1, 1435, NULL, 0.00, NULL, 6290, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1436, 1, 21, 'Bell Helmet Custom 500 Retro Blue - L', 'Bell Helmet Custom 500 Retro Blue - L', 2, 1, 1436, NULL, 0.00, NULL, 6290, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 0),
	(1437, 1, 21, 'Bell Helmet Custom 500 Matte Black - M', 'Bell Helmet Custom 500 Matte Black - M', 2, 1, 1437, NULL, 0.00, NULL, 6590, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1438, 1, 21, 'BELL HELMET QUALIFIER CAM GREEN - L', 'BELL HELMET QUALIFIER CAM GREEN - L', 2, 1, 1438, NULL, 0.00, NULL, 5380, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '7047828', NULL, 'SHOW ROOM', 5),
	(1439, 1, 21, 'BELL HELMET PS SX-1 SWITCH ORANGE - M', 'BELL HELMET PS SX-1 SWITCH ORANGE - M', 2, 1, 1439, NULL, 0.00, NULL, 5555, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1440, 16, 31, 'Spyder Shift GD 972 L Ylw/Blu/Gr - GD972', 'Spyder Shift GD 972 L Ylw/Blu/Gr - GD972', 2, 1, 1440, NULL, 0.00, NULL, 4730, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1441, 16, 31, 'Spyder Shift GD 362 L Blk/Red S2 - GD362', 'Spyder Shift GD 362 L Blk/Red S2 - GD362', 2, 1, 1441, NULL, 0.00, NULL, 4730, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1442, 16, 31, 'Spyder Heat GD 361 L Blk/Rd/Gry - GD361', 'Spyder Heat GD 361 L Blk/Rd/Gry - GD361', 2, 1, 1442, NULL, 0.00, NULL, 4040, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1443, 16, 31, 'Spyder Shift GD 992 L Pnk/Ylw/Gr', 'Spyder Shift GD 992 L Pnk/Ylw/Gr', 2, 1, 1443, NULL, 0.00, NULL, 4505, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1444, 2, 20, 'Kyt Helmet Cl - Primo #2 Neon Orange/Gun Metal - XL', 'Kyt Helmet Cl - Primo #2 Neon Orange/Gun Metal - XL', 2, 1, 1444, NULL, 0.00, NULL, 4150, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1445, 2, 20, 'Kyt Helmet RC Seven #5 Blk/Red/Orange/Gun Metal - M', 'Kyt Helmet RC Seven #5 Blk/Red/Orange/Gun Metal - M', 2, 1, 1445, NULL, 0.00, NULL, 3675, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1446, 3, 26, 'Motorex Formula Semi Synthetic 4T 15W-50', 'Motorex Formula Semi Synthetic 4T 15W-50', 7, 4, 1446, NULL, 0.00, NULL, 655, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '301617', NULL, 'STOCK ROOM', 8),
	(1447, 3, 26, 'Motorex Scooter Oil 4T 10w-40', 'Motorex Scooter Oil 4T 10w-40', 7, 4, 1447, NULL, 0.00, NULL, 670, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '302102', NULL, 'STOCK ROOM', 8),
	(1448, 3, 17, 'Yuasa Batter - YTZ10S-JP', 'Yuasa Batter - YTZ10S-JP', 6, 1, 1448, NULL, 0.00, NULL, 9988, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1449, 4, 8, 'NGK Sparkplug Ktm D200/390 ', 'NGK Sparkplug Ktm D200/390 ', 1, 1, 1449, NULL, 0.00, NULL, 1320, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, 'LKAR8A1-9', NULL, 'SHOW ROOM', 5),
	(1450, 6, 1, 'Clutch Cable - D200', 'Clutch Cable - D200', 1, 1, 1450, NULL, 0.00, NULL, 2090, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '90102090000', NULL, 'SHOW ROOM', 5),
	(1451, 6, 1, 'Foot Brake Lever ', 'Foot Brake Lever ', 1, 1, 1451, NULL, 0.00, NULL, 2310, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '90113050133', NULL, 'SHOW ROOM', 5),
	(1452, 21, 8, 'Denali Sound Bomb Air Horn - Denit - SB-I', 'Denali Sound Bomb Air Horn - Denit - SB-I', 1, 9, 1452, NULL, 0.00, NULL, 6240, '2015-11-25', 0, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1453, 6, 7, 'Jacket SCR Sprocket M ', 'Jacket SCR Sprocket M ', 2, 1, 1453, NULL, 0.00, NULL, 11330, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691704- - T6', NULL, 'SHOW ROOM', 5),
	(1454, 6, 7, 'Jacket SCR Sprocket XL ', 'Jacket SCR Sprocket XL ', 2, 1, 1454, NULL, 0.00, NULL, 11330, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691706 - T6', NULL, 'SHOW ROOM', 5),
	(1455, 6, 7, 'Heritage SCR T-shirt L ', 'Heritage SCR T-shirt L ', 2, 1, 1455, NULL, 0.00, NULL, 3410, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691765 - T6', NULL, 'SHOW ROOM', 5),
	(1456, 6, 7, 'Heritage SCR T-shirt XL ', 'Heritage SCR T-shirt XL ', 2, 1, 1456, NULL, 0.00, NULL, 3410, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691766 - T6', NULL, 'SHOW ROOM', 5),
	(1457, 6, 7, 'MOAB SCR T-shirt XL ', 'MOAB SCR T-shirt XL ', 2, 1, 1457, NULL, 0.00, NULL, 3410, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691826- T6', NULL, 'SHOW ROOM', 5),
	(1458, 6, 7, 'Short Trackers SCR T-shirt M ', 'Short Trackers SCR T-shirt M ', 2, 1, 1458, NULL, 0.00, NULL, 3410, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691774 - T6 ', NULL, 'SHOW ROOM', 5),
	(1459, 6, 7, 'Short Trackers SCR T-shirt XL', 'Short Trackers SCR T-shirt XL', 2, 1, 1459, NULL, 0.00, NULL, 3410, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691776 - T6', NULL, 'SHOW ROOM', 5),
	(1460, 6, 7, 'Rumble SCR T-shirt M ', 'Rumble SCR T-shirt M ', 2, 1, 1460, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691784 - T6', NULL, 'SHOW ROOM', 5),
	(1461, 6, 7, 'Ghost Rider SCR T-shirt M', 'Ghost Rider SCR T-shirt M', 2, 1, 1461, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691804 - T6', NULL, 'SHOW ROOM', 5),
	(1462, 6, 7, 'Ghost Rider SCR T-shirt XL', 'Ghost Rider SCR T-shirt XL', 2, 1, 1462, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691806 - T6', NULL, 'SHOW ROOM', 5),
	(1463, 6, 7, 'Rumble SCR T-shirt L ', 'Rumble SCR T-shirt L ', 2, 1, 1463, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691785 - T6', NULL, 'SHOW ROOM', 5),
	(1464, 6, 7, 'Big Banner SCR T-shirt L ', 'Big Banner SCR T-shirt L ', 2, 1, 1464, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691815 - T6', NULL, 'SHOW ROOM', 5),
	(1465, 6, 7, 'Milestone SCR T-shirt L ', 'Milestone SCR T-shirt L ', 2, 1, 1465, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691885 - T6', NULL, 'SHOW ROOM', 5),
	(1466, 6, 7, 'Milestone SCR T-shirt XL ', 'Milestone SCR T-shirt XL ', 2, 1, 1466, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691886 - T6', NULL, 'SHOW ROOM', 5),
	(1467, 6, 7, 'T-shirt MOAB SCR Lady XS ', 'T-shirt MOAB SCR Lady XS ', 2, 1, 1467, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691842 - T6', NULL, 'SHOW ROOM', 5),
	(1468, 6, 7, 'T-shirt Heritage SCR Lady S ', 'T-shirt Heritage SCR Lady S ', 2, 1, 1468, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691833 - T6', NULL, 'SHOW ROOM', 5),
	(1469, 6, 7, 'Cap SCR MOAB ', 'Cap SCR MOAB ', 2, 1, 1469, NULL, 0.00, NULL, 1760, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691710 - T6', NULL, 'SHOW ROOM', 5),
	(1470, 6, 7, 'T-shirt Midnight SCR Lady XS ', 'T-shirt Midnight SCR Lady XS ', 2, 1, 1470, NULL, 0.00, NULL, 2860, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '987691852 - T6', NULL, 'SHOW ROOM', 5),
	(1471, 6, 0, 'Ducati Scrambler Icon Yellow 2015 - NDC Demo Bike ', 'Ducati Scrambler Icon Yellow 2015 - NDC Demo Bike ', 3, 3, 1471, NULL, 0.00, NULL, 540000, '2015-11-25', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1472, 3, 8, 'Kawasaki Oil Filter Assy', 'Kawasaki Oil Filter Assy', 1, 1, 1472, NULL, 0.00, NULL, 925, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '16097-0008', NULL, 'SHOW ROOM', 5),
	(1473, 6, 7, 'Handle Bar-SCR', 'Handle Bar-SCR', 1, 1, 1473, NULL, 0.00, NULL, 5705, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '36011761BA', NULL, 'SHOW ROOM', 5),
	(1474, 6, 7, 'Rear-View Mirror L.H.', 'Rear-View Mirror L.H.', 1, 1, 1474, NULL, 0.00, NULL, 5705, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '52310481B', NULL, 'SHOW ROOM', 5),
	(1475, 6, 7, 'Rear-View MIrror R.H.', 'Rear-View MIrror R.H.', 1, 1, 1475, NULL, 0.00, NULL, 5705, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '52310491B', NULL, 'SHOW ROOM', 5),
	(1476, 6, 7, 'Ducati Oil Filter ', 'Ducati Oil Filter ', 1, 1, 1476, NULL, 0.00, NULL, 965, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '444400355', NULL, 'SHOW ROOM', 0),
	(1477, 4, 8, 'K&N Oil Filter - KN-153', 'K&N Oil Filter - KN-153', 1, 1, 1477, NULL, 0.00, NULL, 1390, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1478, 7, 8, 'BONNVILLE AIR JACKET BLACK/WHITE/RED (S)-330471', 'Bonnville Air Jacket Black/White/Red (S)-330471', 2, 1, 1478, NULL, 0.00, NULL, 10780, '2015-12-12', 112, NULL, '2015-12-12', 'BRAND NEW', 0, '', '_', '_', 5),
	(1479, 16, 8, 'Spyder Phoenix P690 M Red', 'Spyder Phoenix P690 M Red', 1, 1, 1479, NULL, 0.00, NULL, 2655, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1480, 16, 8, 'Spyder Helmet Bourne Yellow/Orange L', 'Spyder Helmet Bourne Yellow/Orange L', 1, 1, 1480, NULL, 0.00, NULL, 2310, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'STOCK ROOM', 8),
	(1481, 14, 8, 'Motorcycle Ramp Aluminum - 018833', 'Motorcycle Ramp Aluminum - 018833', 1, 1, 1481, NULL, 0.00, NULL, 7000, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'STOCK ROOM', 8),
	(1482, 14, 1, 'Bikers Rear Footrest Duke 200 - 021576', 'Bikers Rear Footrest Duke 200 - 021576', 1, 9, 1482, NULL, 0.00, NULL, 14720, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1483, 7, 1, 'Brake Pad Set Front', 'Brake Pad Set Front', 1, 9, 1483, NULL, 0.00, NULL, 1840, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '90113030000-G7', NULL, 'SHOW ROOM', 5),
	(1484, 6, 1, 'Duke 200 Stator Cpl ', 'Duke 200 Stator Cpl ', 1, 9, 1484, NULL, 0.00, NULL, 8045, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '90139004000-T6', NULL, 'SHOW ROOM', 5),
	(1485, 0, 8, 'Vespa Davao T-shirt White - Medium ', 'Vespa Davao T-shirt White - Medium ', 1, 1, 1485, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1486, 0, 8, 'Vespa Davao T-shirt White - Large', 'Vespa Davao T-shirt White - Large', 1, 1, 1486, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1487, 0, 8, 'Vespa Davao T-shirt White - XLarge', 'Vespa Davao T-shirt White - XLarge', 1, 1, 1487, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1488, 0, 1, 'Ktm Davao T-shirt White - Small ', 'Ktm Davao T-shirt White - Small ', 1, 1, 1488, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1489, 0, 1, 'Ktm Davao T-shirt White - XLarge', 'Ktm Davao T-shirt White - XLarge', 1, 1, 1489, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1490, 0, 1, 'Ktm Davao T-shirt White - 2XLarge', 'Ktm Davao T-shirt White - 2XLarge', 1, 1, 1490, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1491, 0, 1, 'Ktm Davao T-shirt Orange - XLarge', 'Ktm Davao T-shirt Orange - XLarge', 1, 1, 1491, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1492, 0, 1, 'Ktm Davao T-shirt Orange - 2XLarge', 'Ktm Davao T-shirt Orange - 2XLarge', 1, 1, 1492, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1493, 0, 7, 'Ducati Davao T-shirt White - Large ', 'Ducati Davao T-shirt White - Large ', 1, 1, 1493, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1494, 0, 7, 'Ducati Davao T-shirt White - XLarge ', 'Ducati Davao T-shirt White - XLarge ', 1, 1, 1494, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5),
	(1495, 0, 7, 'Ducati Davao T-shirt White - 2XLarge ', 'Ducati Davao T-shirt White - 2XLarge ', 1, 1, 1495, NULL, 0.00, NULL, 550, '2015-12-12', 112, NULL, NULL, 'BRAND NEW', 0, '', NULL, 'SHOW ROOM', 5);
/*!40000 ALTER TABLE `tblitem` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitembarcode
DROP TABLE IF EXISTS `tblitembarcode`;
CREATE TABLE IF NOT EXISTS `tblitembarcode` (
  `idBarcode` int(15) DEFAULT NULL,
  `pk` int(10) unsigned zerofill NOT NULL,
  `itemBarcode` varchar(25) NOT NULL,
  `idOrder` int(15) NOT NULL,
  `idItem` int(15) NOT NULL,
  `idSales` int(15) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitembarcode: ~0 rows (approximately)
/*!40000 ALTER TABLE `tblitembarcode` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblitembarcode` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitembrand
DROP TABLE IF EXISTS `tblitembrand`;
CREATE TABLE IF NOT EXISTS `tblitembrand` (
  `idBrand` int(3) NOT NULL DEFAULT '0',
  `brandName` varchar(100) DEFAULT NULL,
  `idCategory` int(3) NOT NULL,
  PRIMARY KEY (`idBrand`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitembrand: ~40 rows (approximately)
/*!40000 ALTER TABLE `tblitembrand` DISABLE KEYS */;
INSERT INTO `tblitembrand` (`idBrand`, `brandName`, `idCategory`) VALUES
	(1, 'KTM', 2),
	(2, 'KTM', 1),
	(3, 'KTM', 3),
	(4, 'Piaggio', 3),
	(5, 'Vespa', 3),
	(6, 'Husqavarna', 3),
	(7, 'DUCATI', 1),
	(8, 'Others', 4),
	(9, 'DUCATI', 2),
	(10, 'Piaggio', 2),
	(11, 'Vespa', 2),
	(12, 'Alpinestar', 2),
	(13, 'PUMA', 2),
	(14, 'Pirelli', 5),
	(15, 'Metzeler', 5),
	(16, 'Motobatt', 6),
	(17, 'Yuasa', 6),
	(18, 'Shell', 7),
	(19, 'Castrol', 7),
	(20, 'KYT', 2),
	(21, 'BELL Helmets', 2),
	(22, 'DUCATI', 3),
	(23, 'Husqavarna', 1),
	(24, 'Aprilia', 1),
	(25, 'Others', 1),
	(26, 'Motorex', 7),
	(27, 'Piaggio', 1),
	(28, 'Others', 7),
	(29, 'Yamaha', 3),
	(30, 'Kawasaki', 3),
	(31, 'Spyder Helmets', 2),
	(32, 'MSR Helmets', 2),
	(33, 'RR Battery', 6),
	(35, 'Honda Motorbikes', 3),
	(36, 'TOTAL', 7),
	(37, 'Vespa', 8),
	(38, 'Harley Davidson', 3),
	(39, 'Polaris', 3),
	(40, 'Acerbis', 2),
	(41, 'Others', 2),
	(42, 'Italjet ', 3);
/*!40000 ALTER TABLE `tblitembrand` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemcategory
DROP TABLE IF EXISTS `tblitemcategory`;
CREATE TABLE IF NOT EXISTS `tblitemcategory` (
  `idCategory` int(3) NOT NULL DEFAULT '0',
  `Category` varchar(60) DEFAULT NULL,
  PRIMARY KEY (`idCategory`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemcategory: ~8 rows (approximately)
/*!40000 ALTER TABLE `tblitemcategory` DISABLE KEYS */;
INSERT INTO `tblitemcategory` (`idCategory`, `Category`) VALUES
	(1, 'Parts & Accessories'),
	(2, 'Apparel & Merchandise'),
	(3, 'Motorbikes'),
	(4, 'Others'),
	(5, 'Tires & Inner Tubes'),
	(6, 'Batterries'),
	(7, 'Oils & Lubricants'),
	(8, 'Consigned Items');
/*!40000 ALTER TABLE `tblitemcategory` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemhistory
DROP TABLE IF EXISTS `tblitemhistory`;
CREATE TABLE IF NOT EXISTS `tblitemhistory` (
  `idHistory` int(20) NOT NULL AUTO_INCREMENT,
  `transDate` date DEFAULT NULL,
  `transID` int(15) DEFAULT NULL,
  `transNo` varchar(15) DEFAULT NULL,
  `transDesc` varchar(50) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `qtyBeg` int(15) DEFAULT NULL,
  `qtyIn` int(15) DEFAULT NULL,
  `qtyOut` int(15) DEFAULT NULL,
  `qtyEnd` int(15) DEFAULT NULL,
  `amount` double(18,2) DEFAULT NULL,
  `unit` varchar(20) DEFAULT NULL,
  `idCategory` int(10) DEFAULT NULL,
  `idBrand` int(10) DEFAULT NULL,
  `idSupplier` int(10) DEFAULT NULL,
  `remarks` varchar(250) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `partNum` varchar(50) DEFAULT NULL,
  `transby` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`idHistory`)
) ENGINE=InnoDB AUTO_INCREMENT=322 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemhistory: ~321 rows (approximately)
/*!40000 ALTER TABLE `tblitemhistory` DISABLE KEYS */;
INSERT INTO `tblitemhistory` (`idHistory`, `transDate`, `transID`, `transNo`, `transDesc`, `code`, `qtyBeg`, `qtyIn`, `qtyOut`, `qtyEnd`, `amount`, `unit`, `idCategory`, `idBrand`, `idSupplier`, `remarks`, `status`, `partNum`, `transby`) VALUES
	(1, '2015-07-31', 0, '0', 'BEG', 731, 1, 0, 0, 1, 130.90, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(2, '2015-07-31', 0, '0', 'BEG', 1371, 37, 0, 0, 37, 377.68, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(3, '2015-07-31', 0, '0', 'BEG', 318, 2, 0, 0, 2, 385.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(4, '2015-07-31', 0, '0', 'BEG', 327, 3, 0, 0, 3, 2275.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(5, '2015-07-31', 0, '0', 'BEG', 337, 3, 0, 0, 3, 0.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(6, '2015-07-31', 0, '0', 'BEG', 362, 3, 0, 0, 3, 5223.21, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(7, '2015-07-31', 0, '0', 'BEG', 444, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(8, '2015-07-31', 0, '0', 'BEG', 900, 1, 0, 0, 1, 841.07, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(9, '2015-07-31', 0, '0', 'BEG', 980, 1, 0, 0, 1, 1089.29, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(10, '2015-07-31', 0, '0', 'BEG', 1017, 1, 0, 0, 1, 8995.54, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(11, '2015-07-31', 0, '0', 'BEG', 45, 1, 0, 0, 1, 6720.54, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(12, '2015-07-31', 0, '0', 'BEG', 26, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 4, 0, 'Beginning', NULL, '', 'system'),
	(13, '2015-07-31', 0, '0', 'BEG', 732, 46, 0, 0, 46, 130.90, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(14, '2015-07-31', 0, '0', 'BEG', 310, 1, 0, 0, 1, 644.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(15, '2015-07-31', 0, '0', 'BEG', 1362, 12, 0, 0, 12, 111.61, 'Pc(s)', 7, 19, 0, 'Beginning', NULL, '', 'system'),
	(16, '2015-07-31', 0, '0', 'BEG', 1074, 1, 0, 0, 1, 1062.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(17, '2015-07-31', 0, '0', 'BEG', 739, 1, 0, 0, 1, 8571.43, 'Pair(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(18, '2015-07-31', 0, '0', 'BEG', 747, 2, 0, 0, 2, 4000.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(19, '2015-07-31', 0, '0', 'BEG', 763, 4, 0, 0, 4, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(20, '2015-07-31', 0, '0', 'BEG', 1150, 1, 0, 0, 1, 1714.29, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(21, '2015-07-31', 0, '0', 'BEG', 1182, 1, 0, 0, 1, 5531.25, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(22, '2015-07-31', 0, '0', 'BEG', 1206, 1, 0, 0, 1, 3000.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(23, '2015-07-31', 0, '0', 'BEG', 1223, 1, 0, 0, 1, 2396.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(24, '2015-07-31', 0, '0', 'BEG', 1260, 1, 0, 0, 1, 2946.43, 'Pair(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(25, '2015-07-31', 0, '0', 'BEG', 1289, 1, 0, 0, 1, 3357.14, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(26, '2015-07-31', 0, '0', 'BEG', 1006, 1, 0, 0, 1, 2424.11, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(27, '2015-07-31', 0, '0', 'BEG', 1016, 1, 0, 0, 1, 8995.54, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(28, '2015-07-31', 0, '0', 'BEG', 1066, 1, 0, 0, 1, 1062.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(29, '2015-07-31', 0, '0', 'BEG', 756, 2, 0, 0, 2, 100.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(30, '2015-07-31', 0, '0', 'BEG', 764, 3, 0, 0, 3, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(31, '2015-07-31', 0, '0', 'BEG', 311, 1, 0, 0, 1, 1085.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(32, '2015-07-31', 0, '0', 'BEG', 319, 1, 0, 0, 1, 385.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(33, '2015-07-31', 0, '0', 'BEG', 329, 11, 0, 0, 11, 2275.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(34, '2015-07-31', 0, '0', 'BEG', 338, 5, 0, 0, 5, 0.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(35, '2015-07-31', 0, '0', 'BEG', 346, 2, 0, 0, 2, 910.71, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(36, '2015-07-31', 0, '0', 'BEG', 155, 4, 0, 0, 4, 503.00, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(37, '2015-07-31', 0, '0', 'BEG', 74, 1, 0, 0, 1, 4501.98, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(38, '2015-07-31', 0, '0', 'BEG', 115, 1, 0, 0, 1, 5514.29, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(39, '2015-07-31', 0, '0', 'BEG', 537, 28, 0, 0, 28, 295.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(40, '2015-07-31', 0, '0', 'BEG', 634, 2, 0, 0, 2, 580.36, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(41, '2015-07-31', 0, '0', 'BEG', 40, 1, 0, 0, 1, 43140.18, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(42, '2015-07-31', 0, '0', 'BEG', 922, 1, 0, 0, 1, 1767.86, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(43, '2015-07-31', 0, '0', 'BEG', 295, 3, 0, 0, 3, 1225.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(44, '2015-07-31', 0, '0', 'BEG', 1183, 1, 0, 0, 1, 5531.25, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(45, '2015-07-31', 0, '0', 'BEG', 1143, 1, 0, 0, 1, 1406.25, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(46, '2015-07-31', 0, '0', 'BEG', 796, 1, 0, 0, 1, 145.85, 'Pc(s)', 2, 41, 0, 'Beginning', NULL, '', 'system'),
	(47, '2015-07-31', 0, '0', 'BEG', 18, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 3, 0, 'Beginning', NULL, '', 'system'),
	(48, '2015-07-31', 0, '0', 'BEG', 1232, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 21, 0, 'Beginning', NULL, '', 'system'),
	(49, '2015-07-31', 0, '0', 'BEG', 1290, 1, 0, 0, 1, 6865.51, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(50, '2015-07-31', 0, '0', 'BEG', 1340, 1, 0, 0, 1, 0.00, 'Pc(s)', 6, 17, 0, 'Beginning', NULL, '', 'system'),
	(51, '2015-07-31', 0, '0', 'BEG', 1375, 10, 0, 0, 10, 337.50, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(52, '2015-07-31', 0, '0', 'BEG', 829, 1, 0, 0, 1, 0.00, 'Pair(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(53, '2015-07-31', 0, '0', 'BEG', 1224, 1, 0, 0, 1, 1721.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(54, '2015-07-31', 0, '0', 'BEG', 1207, 1, 0, 0, 1, 3000.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(55, '2015-07-31', 0, '0', 'BEG', 1059, 1, 0, 0, 1, 1241.07, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(56, '2015-07-31', 0, '0', 'BEG', 1086, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(57, '2015-07-31', 0, '0', 'BEG', 1094, 5, 0, 0, 5, 450.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(58, '2015-07-31', 0, '0', 'BEG', 983, 1, 0, 0, 1, 1089.29, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(59, '2015-07-31', 0, '0', 'BEG', 633, 1, 0, 0, 1, 730.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(60, '2015-07-31', 0, '0', 'BEG', 1103, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(61, '2015-07-31', 0, '0', 'BEG', 646, 4, 0, 0, 4, 2386.61, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(62, '2015-07-31', 0, '0', 'BEG', 728, 1, 0, 0, 1, 285.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(63, '2015-07-31', 0, '0', 'BEG', 1179, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(64, '2015-07-31', 0, '0', 'BEG', 1220, 2, 0, 0, 2, 2396.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(65, '2015-07-31', 0, '0', 'BEG', 1228, 1, 0, 0, 1, 2295.00, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(66, '2015-07-31', 0, '0', 'BEG', 1236, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 20, 0, 'Beginning', NULL, '', 'system'),
	(67, '2015-07-31', 0, '0', 'BEG', 1248, 1, 0, 0, 1, 3125.00, 'Pair(s)', 2, 13, 0, 'Beginning', NULL, '', 'system'),
	(68, '2015-07-31', 0, '0', 'BEG', 1302, 1, 0, 0, 1, 0.00, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(69, '2015-07-31', 0, '0', 'BEG', 1131, 1, 0, 0, 1, 1441.07, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(70, '2015-07-31', 0, '0', 'BEG', 1013, 1, 0, 0, 1, 5107.14, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(71, '2015-07-31', 0, '0', 'BEG', 1039, 1, 0, 0, 1, 1681.25, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(72, '2015-07-31', 0, '0', 'BEG', 1055, 1, 0, 0, 1, 1062.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(73, '2015-07-31', 0, '0', 'BEG', 800, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 23, 0, 'Beginning', NULL, '', 'system'),
	(74, '2015-07-31', 0, '0', 'BEG', 808, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 41, 0, 'Beginning', NULL, '', 'system'),
	(75, '2015-07-31', 0, '0', 'BEG', 923, 1, 0, 0, 1, 1767.86, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(76, '2015-07-31', 0, '0', 'BEG', 1128, 1, 0, 0, 1, 1714.29, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(77, '2015-07-31', 0, '0', 'BEG', 1368, 8, 0, 0, 8, 466.07, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(78, '2015-07-31', 0, '0', 'BEG', 296, 1, 0, 0, 1, 295.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(79, '2015-07-31', 0, '0', 'BEG', 304, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(80, '2015-07-31', 0, '0', 'BEG', 320, 3, 0, 0, 3, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(81, '2015-07-31', 0, '0', 'BEG', 331, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(82, '2015-07-31', 0, '0', 'BEG', 339, 1, 0, 0, 1, 2799.11, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(83, '2015-07-31', 0, '0', 'BEG', 825, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(84, '2015-07-31', 0, '0', 'BEG', 14, 2, 0, 0, 2, 0.00, 'Unit(s)', 3, 3, 0, 'Beginning', NULL, '', 'system'),
	(85, '2015-07-31', 0, '0', 'BEG', 22, 11, 0, 0, 11, 0.00, 'Unit(s)', 3, 3, 0, 'Beginning', NULL, '', 'system'),
	(86, '2015-07-31', 0, '0', 'BEG', 41, 1, 0, 0, 1, 7180.36, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(87, '2015-07-31', 0, '0', 'BEG', 914, 1, 0, 0, 1, 12321.43, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(88, '2015-07-31', 0, '0', 'BEG', 1063, 1, 0, 0, 1, 1535.71, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(89, '2015-07-31', 0, '0', 'BEG', 1090, 3, 0, 0, 3, 0.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(90, '2015-07-31', 0, '0', 'BEG', 334, 6, 0, 0, 6, 2920.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(91, '2015-07-31', 0, '0', 'BEG', 500, 1, 0, 0, 1, 1251.79, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(92, '2015-07-31', 0, '0', 'BEG', 525, 1, 0, 0, 1, 321.43, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(93, '2015-07-31', 0, '0', 'BEG', 384, 3, 0, 0, 3, 2216.07, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(94, '2015-07-31', 0, '0', 'BEG', 441, 2, 0, 0, 2, 535.71, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(95, '2015-07-31', 0, '0', 'BEG', 449, 3, 0, 0, 3, 428.57, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(96, '2015-07-31', 0, '0', 'BEG', 1354, 22, 0, 0, 22, 378.57, 'Ltr(s)', 7, 19, 0, 'Beginning', NULL, '', 'system'),
	(97, '2015-07-31', 0, '0', 'BEG', 828, 1, 0, 0, 1, 2290.18, 'Pair(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(98, '2015-07-31', 0, '0', 'BEG', 17, 4, 0, 0, 4, 0.00, 'Unit(s)', 3, 3, 0, 'Beginning', NULL, '', 'system'),
	(99, '2015-07-31', 0, '0', 'BEG', 36, 2, 0, 0, 2, 0.00, 'Set(s)', 1, 7, 0, 'Beginning', NULL, '54040191A', 'system'),
	(100, '2015-07-31', 0, '0', 'BEG', 44, 1, 0, 0, 1, 6369.64, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(101, '2015-07-31', 0, '0', 'BEG', 811, 195, 0, 0, 195, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(102, '2015-07-31', 0, '0', 'BEG', 324, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(103, '2015-07-31', 0, '0', 'BEG', 103, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(104, '2015-07-31', 0, '0', 'BEG', 70, 1, 0, 0, 1, 4468.36, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(105, '2015-07-31', 0, '0', 'BEG', 1098, 2, 0, 0, 2, 450.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(106, '2015-07-31', 0, '0', 'BEG', 1334, 2, 0, 0, 2, 2883.93, 'Pc(s)', 6, 16, 0, 'Beginning', NULL, '', 'system'),
	(107, '2015-07-31', 0, '0', 'BEG', 1376, 1, 0, 0, 1, 377.68, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(108, '2015-07-31', 0, '0', 'BEG', 291, 2, 0, 0, 2, 4130.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(109, '2015-07-31', 0, '0', 'BEG', 307, 11, 0, 0, 11, 2415.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(110, '2015-07-31', 0, '0', 'BEG', 315, 2, 0, 0, 2, 1382.50, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(111, '2015-07-31', 0, '0', 'BEG', 119, 1, 0, 0, 1, 5514.29, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(112, '2015-07-31', 0, '0', 'BEG', 111, 1, 0, 0, 1, 1169.64, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(113, '2015-07-31', 0, '0', 'BEG', 830, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(114, '2015-07-31', 0, '0', 'BEG', 854, 2, 0, 0, 2, 0.00, 'Set(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(115, '2015-07-31', 0, '0', 'BEG', 871, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(116, '2015-07-31', 0, '0', 'BEG', 879, 197, 0, 0, 197, 35.71, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(117, '2015-07-31', 0, '0', 'BEG', 803, 2, 0, 0, 2, 150.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(118, '2015-07-31', 0, '0', 'BEG', 1053, 1, 0, 0, 1, 1062.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(119, '2015-07-31', 0, '0', 'BEG', 1137, 1, 0, 0, 1, 1540.18, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(120, '2015-07-31', 0, '0', 'BEG', 1177, 1, 0, 0, 1, 19285.71, 'Pair(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(121, '2015-07-31', 0, '0', 'BEG', 1209, 1, 0, 0, 1, 3000.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(122, '2015-07-31', 0, '0', 'BEG', 1218, 1, 0, 0, 1, 3213.00, 'Pc(s)', 2, 21, 0, 'Beginning', NULL, '', 'system'),
	(123, '2015-07-31', 0, '0', 'BEG', 872, 11, 0, 0, 11, 35.71, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(124, '2015-07-31', 0, '0', 'BEG', 297, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(125, '2015-07-31', 0, '0', 'BEG', 305, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(126, '2015-07-31', 0, '0', 'BEG', 321, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(127, '2015-07-31', 0, '0', 'BEG', 332, 7, 0, 0, 7, 700.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(128, '2015-07-31', 0, '0', 'BEG', 67, 1, 0, 0, 1, 2980.36, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(129, '2015-07-31', 0, '0', 'BEG', 117, 1, 0, 0, 1, 4320.62, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(130, '2015-07-31', 0, '0', 'BEG', 726, 18, 0, 0, 18, 15.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(131, '2015-07-31', 0, '0', 'BEG', 1104, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(132, '2015-07-31', 0, '0', 'BEG', 1096, 5, 0, 0, 5, 450.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(133, '2015-07-31', 0, '0', 'BEG', 904, 1, 0, 0, 1, 937.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(134, '2015-07-31', 0, '0', 'BEG', 798, 3, 0, 0, 3, 80.00, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(135, '2015-07-31', 0, '0', 'BEG', 2, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 22, 0, 'Beginning', NULL, '', 'system'),
	(136, '2015-07-31', 0, '0', 'BEG', 39, 1, 0, 0, 1, 8775.00, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(137, '2015-07-31', 0, '0', 'BEG', 1061, 1, 0, 0, 1, 1062.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(138, '2015-07-31', 0, '0', 'BEG', 1255, 1, 0, 0, 1, 1964.29, 'Pair(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(139, '2015-07-31', 0, '0', 'BEG', 1221, 2, 0, 0, 2, 0.00, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(140, '2015-07-31', 0, '0', 'BEG', 1360, 14, 0, 0, 14, 260.72, 'Ltr(s)', 7, 19, 0, 'Beginning', NULL, '', 'system'),
	(141, '2015-07-31', 0, '0', 'BEG', 1369, 14, 0, 0, 14, 498.86, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(142, '2015-07-31', 0, '0', 'BEG', 831, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(143, '2015-07-31', 0, '0', 'BEG', 1242, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 46, 0, 'Beginning', NULL, '', 'system'),
	(144, '2015-07-31', 0, '0', 'BEG', 1226, 1, 0, 0, 1, 1871.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(145, '2015-07-31', 0, '0', 'BEG', 522, 3, 0, 0, 3, 313.01, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(146, '2015-07-31', 0, '0', 'BEG', 734, 14, 0, 0, 14, 140.90, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(147, '2015-07-31', 0, '0', 'BEG', 907, 1, 0, 0, 1, 937.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(148, '2015-07-31', 0, '0', 'BEG', 1372, 9, 0, 0, 9, 385.71, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(149, '2015-07-31', 0, '0', 'BEG', 1091, 2, 0, 0, 2, 0.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(150, '2015-07-31', 0, '0', 'BEG', 1099, 2, 0, 0, 2, 450.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(151, '2015-07-31', 0, '0', 'BEG', 1148, 1, 0, 0, 1, 1142.86, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(152, '2015-07-31', 0, '0', 'BEG', 1180, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(153, '2015-07-31', 0, '0', 'BEG', 737, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(154, '2015-07-31', 0, '0', 'BEG', 292, 1, 0, 0, 1, 8500.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(155, '2015-07-31', 0, '0', 'BEG', 316, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(156, '2015-07-31', 0, '0', 'BEG', 325, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(157, '2015-07-31', 0, '0', 'BEG', 351, 5, 0, 0, 5, 642.86, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(158, '2015-07-31', 0, '0', 'BEG', 120, 1, 0, 0, 1, 4320.62, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(159, '2015-07-31', 0, '0', 'BEG', 402, 2, 0, 0, 2, 9040.18, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(160, '2015-07-31', 0, '0', 'BEG', 1364, 12, 0, 0, 12, 466.07, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(161, '2015-07-31', 0, '0', 'BEG', 1303, 1, 0, 0, 1, 0.00, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(162, '2015-07-31', 0, '0', 'BEG', 1014, 1, 0, 0, 1, 5107.14, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(163, '2015-07-31', 0, '0', 'BEG', 42, 1, 0, 0, 1, 6881.25, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(164, '2015-07-31', 0, '0', 'BEG', 729, 1, 0, 0, 1, 900.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(165, '2015-07-31', 0, '0', 'BEG', 793, 2, 0, 0, 2, 100.00, 'Pc(s)', 2, 41, 0, 'Beginning', NULL, '', 'system'),
	(166, '2015-07-31', 0, '0', 'BEG', 801, 1, 0, 0, 1, 80.00, 'Pc(s)', 1, 27, 0, 'Beginning', NULL, '', 'system'),
	(167, '2015-07-31', 0, '0', 'BEG', 809, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(168, '2015-07-31', 0, '0', 'BEG', 818, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(169, '2015-07-31', 0, '0', 'BEG', 826, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(170, '2015-07-31', 0, '0', 'BEG', 23, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 40, 0, 'Beginning', NULL, '', 'system'),
	(171, '2015-07-31', 0, '0', 'BEG', 1237, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 20, 0, 'Beginning', NULL, '', 'system'),
	(172, '2015-07-31', 0, '0', 'BEG', 1250, 1, 0, 0, 1, 2678.57, 'Pair(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(173, '2015-07-31', 0, '0', 'BEG', 1266, 1, 0, 0, 1, 1205.36, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(174, '2015-07-31', 0, '0', 'BEG', 655, 3, 0, 0, 3, 867.86, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(175, '2015-07-31', 0, '0', 'BEG', 1351, 42, 0, 0, 42, 328.94, 'Ltr(s)', 7, 18, 0, 'Beginning', NULL, '', 'system'),
	(176, '2015-07-31', 0, '0', 'BEG', 298, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(177, '2015-07-31', 0, '0', 'BEG', 322, 2, 0, 0, 2, 803.57, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(178, '2015-07-31', 0, '0', 'BEG', 333, 3, 0, 0, 3, 2920.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(179, '2015-07-31', 0, '0', 'BEG', 870, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(180, '2015-07-31', 0, '0', 'BEG', 1235, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 20, 0, 'Beginning', NULL, '', 'system'),
	(181, '2015-07-31', 0, '0', 'BEG', 878, 120, 0, 0, 120, 178.57, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(182, '2015-07-31', 0, '0', 'BEG', 1219, 1, 0, 0, 1, 2246.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(183, '2015-07-31', 0, '0', 'BEG', 890, 1, 0, 0, 1, 2818.75, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(184, '2015-07-31', 0, '0', 'BEG', 78, 2, 0, 0, 2, 1475.89, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(185, '2015-07-31', 0, '0', 'BEG', 1243, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 48, 0, 'Beginning', NULL, '', 'system'),
	(186, '2015-07-31', 0, '0', 'BEG', 314, 3, 0, 0, 3, 1382.50, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(187, '2015-07-31', 0, '0', 'BEG', 1178, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(188, '2015-07-31', 0, '0', 'BEG', 1097, 1, 0, 0, 1, 450.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(189, '2015-07-31', 0, '0', 'BEG', 1194, 1, 0, 0, 1, 3000.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(190, '2015-07-31', 0, '0', 'BEG', 1210, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(191, '2015-07-31', 0, '0', 'BEG', 306, 2, 0, 0, 2, 2415.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(192, '2015-07-31', 0, '0', 'BEG', 1370, 44, 0, 0, 44, 554.46, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(193, '2015-07-31', 0, '0', 'BEG', 1361, 2, 0, 0, 2, 139.29, 'Ltr(s)', 7, 19, 0, 'Beginning', NULL, '', 'system'),
	(194, '2015-07-31', 0, '0', 'BEG', 1301, 1, 0, 0, 1, 0.00, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(195, '2015-07-31', 0, '0', 'BEG', 564, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(196, '2015-07-31', 0, '0', 'BEG', 383, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(197, '2015-07-31', 0, '0', 'BEG', 440, 4, 0, 0, 4, 589.29, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(198, '2015-07-31', 0, '0', 'BEG', 931, 1, 0, 0, 1, 2589.29, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(199, '2015-07-31', 0, '0', 'BEG', 982, 2, 0, 0, 2, 1089.29, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(200, '2015-07-31', 0, '0', 'BEG', 799, 8, 0, 0, 8, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(201, '2015-07-31', 0, '0', 'BEG', 727, 8, 0, 0, 8, 15.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(202, '2015-07-31', 0, '0', 'BEG', 13, 5, 0, 0, 5, 0.00, 'Unit(s)', 3, 3, 0, 'Beginning', NULL, '', 'system'),
	(203, '2015-07-31', 0, '0', 'BEG', 1011, 1, 0, 0, 1, 343.75, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(204, '2015-07-31', 0, '0', 'BEG', 21, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 3, 0, 'Beginning', NULL, '', 'system'),
	(205, '2015-07-31', 0, '0', 'BEG', 1012, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(206, '2015-07-31', 0, '0', 'BEG', 1305, 1, 0, 0, 1, 5604.91, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(207, '2015-07-31', 0, '0', 'BEG', 877, 200, 0, 0, 200, 35.71, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(208, '2015-07-31', 0, '0', 'BEG', 824, 5, 0, 0, 5, 6500.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(209, '2015-07-31', 0, '0', 'BEG', 1374, 4, 0, 0, 4, 602.68, 'Ltr(s)', 7, 26, 0, 'Beginning', NULL, '', 'system'),
	(210, '2015-07-31', 0, '0', 'BEG', 126, 1, 0, 0, 1, 2139.29, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(211, '2015-07-31', 0, '0', 'BEG', 24, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 40, 0, 'Beginning', NULL, '', 'system'),
	(212, '2015-07-31', 0, '0', 'BEG', 1197, 1, 0, 0, 1, 3750.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(213, '2015-07-31', 0, '0', 'BEG', 1222, 1, 0, 0, 1, 2396.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(214, '2015-07-31', 0, '0', 'BEG', 1304, 1, 0, 0, 1, 0.00, 'Pc(s)', 5, 14, 0, 'Beginning', NULL, '', 'system'),
	(215, '2015-07-31', 0, '0', 'BEG', 1149, 1, 0, 0, 1, 1214.28, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(216, '2015-07-31', 0, '0', 'BEG', 1092, 1, 0, 0, 1, 0.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(217, '2015-07-31', 0, '0', 'BEG', 1108, 1, 0, 0, 1, 2644.64, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(218, '2015-07-31', 0, '0', 'BEG', 1141, 1, 0, 0, 1, 1406.25, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(219, '2015-07-31', 0, '0', 'BEG', 309, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(220, '2015-07-31', 0, '0', 'BEG', 326, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(221, '2015-07-31', 0, '0', 'BEG', 336, 1, 0, 0, 1, 0.00, 'Set(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(222, '2015-07-31', 0, '0', 'BEG', 1015, 1, 0, 0, 1, 5107.14, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(223, '2015-07-31', 0, '0', 'BEG', 819, 1, 0, 0, 1, 562.50, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(224, '2015-07-31', 0, '0', 'BEG', 43, 1, 0, 0, 1, 6604.46, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(225, '2015-07-31', 0, '0', 'BEG', 908, 1, 0, 0, 1, 937.50, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(226, '2015-07-31', 0, '0', 'BEG', 6, 1, 0, 0, 1, 0.00, 'Unit(s)', 3, 22, 0, 'Beginning', NULL, '', 'system'),
	(227, '2015-07-31', 0, '0', 'BEG', 827, 1, 0, 0, 1, 0.00, 'Pair(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(228, '2015-07-31', 0, '0', 'BEG', 697, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 27, 0, 'Beginning', NULL, '', 'system'),
	(229, '2015-07-31', 0, '0', 'BEG', 730, 1, 0, 0, 1, 900.00, 'Pc(s)', 2, 40, 0, 'Beginning', NULL, '', 'system'),
	(230, '2015-07-31', 0, '0', 'BEG', 738, 1, 0, 0, 1, 8571.43, 'Pair(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(231, '2015-07-31', 0, '0', 'BEG', 762, 3, 0, 0, 3, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(232, '2015-07-31', 0, '0', 'BEG', 802, 3, 0, 0, 3, 100.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(233, '2015-07-31', 0, '0', 'BEG', 810, 2, 0, 0, 2, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(234, '2015-07-31', 0, '0', 'BEG', 137, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 7, 0, 'Beginning', NULL, '', 'system'),
	(235, '2015-07-31', 0, '0', 'BEG', 881, 57, 0, 0, 57, 178.57, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(236, '2015-07-31', 0, '0', 'BEG', 773, 1, 0, 0, 1, 482.14, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(237, '2015-07-31', 0, '0', 'BEG', 725, 7, 0, 0, 7, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(238, '2015-07-31', 0, '0', 'BEG', 733, 15, 0, 0, 15, 130.90, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(239, '2015-07-31', 0, '0', 'BEG', 757, 6, 0, 0, 6, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(240, '2015-07-31', 0, '0', 'BEG', 1345, 1, 0, 0, 1, 0.00, 'Pc(s)', 6, 33, 0, 'Beginning', NULL, '', 'system'),
	(241, '2015-07-31', 0, '0', 'BEG', 797, 1, 0, 0, 1, 145.85, 'Pc(s)', 2, 41, 0, 'Beginning', NULL, '', 'system'),
	(242, '2015-07-31', 0, '0', 'BEG', 1018, 1, 0, 0, 1, 8995.54, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(243, '2015-07-31', 0, '0', 'BEG', 1208, 1, 0, 0, 1, 3000.00, 'Pc(s)', 2, 12, 0, 'Beginning', NULL, '', 'system'),
	(244, '2015-07-31', 0, '0', 'BEG', 1225, 1, 0, 0, 1, 1496.25, 'Pc(s)', 2, 31, 0, 'Beginning', NULL, '', 'system'),
	(245, '2015-07-31', 0, '0', 'BEG', 813, 1, 0, 0, 1, 0.00, 'Pc(s)', 1, 25, 0, 'Beginning', NULL, '', 'system'),
	(246, '2015-07-31', 0, '0', 'BEG', 981, 1, 0, 0, 1, 1089.29, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(247, '2015-07-31', 0, '0', 'BEG', 361, 3, 0, 0, 3, 830.36, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(248, '2015-07-31', 0, '0', 'BEG', 485, 2, 0, 0, 2, 267.86, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(249, '2015-07-31', 0, '0', 'BEG', 1095, 9, 0, 0, 9, 450.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(250, '2015-07-31', 0, '0', 'BEG', 1316, 1, 0, 0, 1, 5303.57, 'Pc(s)', 5, 15, 0, 'Beginning', NULL, '', 'system'),
	(251, '2015-07-31', 0, '0', 'BEG', 1087, 1, 0, 0, 1, 5300.00, 'Pc(s)', 2, 1, 0, 'Beginning', NULL, '', 'system'),
	(252, '2015-07-31', 0, '0', 'BEG', 443, 1, 0, 0, 1, 647.00, 'Pc(s)', 1, 2, 0, 'Beginning', NULL, '', 'system'),
	(253, '2015-07-31', 0, '0', 'BEG', 920, 1, 0, 0, 1, 1767.86, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(254, '2015-07-31', 0, '0', 'BEG', 929, 1, 0, 0, 1, 2589.29, 'Pc(s)', 2, 9, 0, 'Beginning', NULL, '', 'system'),
	(255, '2015-08-01', 7, '2015-2', 'SO', 1095, 9, 0, 1, 8, 880.00, 'Pc(s)', 2, 1, 0, 'Sales', NULL, '', 'jpd'),
	(256, '2015-08-03', 2016, '2015-1', 'RCV', 289, 0, 1, 0, 1, 0.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(257, '2015-08-05', 39, '2015-1', 'SVC', 1371, 37, 0, 1, 36, 655.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(258, '2015-08-06', 22, '2015-9', 'SO', 793, 2, 0, 1, 1, 100.00, 'Pc(s)', 2, 41, 0, 'Sales', NULL, '', 'ggt'),
	(259, '2015-08-06', 23, '2015-10', 'SO', 1372, 9, 0, 1, 8, 385.72, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(260, '2015-08-06', 23, '2015-10', 'SO', 1364, 12, 0, 1, 11, 466.07, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(261, '2015-08-06', 23, '2015-10', 'SO', 1360, 14, 0, 1, 13, 260.72, 'Ltr(s)', 7, 19, 0, 'Sales', NULL, '', 'ggt'),
	(262, '2015-08-06', 6, '2015-1', 'SO', 1091, 2, 0, 1, 1, 435.00, 'Pc(s)', 2, 1, 0, 'Sales', NULL, '', 'jpd'),
	(263, '2015-08-06', 22, '2015-9', 'SO', 811, 195, 0, 1, 194, 27.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(264, '2015-08-06', 22, '2015-9', 'SO', 797, 1, 0, 1, 0, 145.85, 'Pc(s)', 2, 41, 0, 'Sales', NULL, '', 'ggt'),
	(265, '2015-08-08', 35, '1', 'INV', 13, 5, 0, 1, 4, 199000.00, 'Unit(s)', 3, 3, 0, 'Sales', NULL, '', 'ggt'),
	(266, '2015-08-11', 2017, '2015-2', 'RCV', 617, 0, 1, 0, 1, 1414.29, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(267, '2015-08-11', 24, '2015-11', 'SO', 811, 194, 0, 1, 193, 27.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'jpd'),
	(268, '2015-08-11', 36, '2', 'INV', 24, 1, 0, 1, 0, 105000.00, 'Unit(s)', 3, 40, 0, 'Sales', NULL, '', 'ggt'),
	(269, '2015-08-12', 14, '2015-3', 'SO', 537, 28, 0, 1, 27, 660.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(270, '2015-08-12', 14, '2015-3', 'SO', 726, 18, 0, 1, 17, 55.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(271, '2015-08-12', 40, '2015-3', 'SVC', 155, 4, 0, 1, 3, 925.00, 'Pc(s)', 1, 7, 0, 'Sales', NULL, '', 'ggt'),
	(272, '2015-08-12', 14, '2015-3', 'SO', 1371, 36, 0, 2, 34, 655.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(273, '2015-08-12', 15, '2015-4', 'SO', 1224, 1, 0, 1, 0, 2655.00, 'Pc(s)', 2, 31, 0, 'Sales', NULL, '', 'jpd'),
	(274, '2015-08-12', 40, '2015-3', 'SVC', 1351, 42, 0, 3, 39, 540.00, 'Ltr(s)', 7, 18, 0, 'Sales', NULL, '', 'ggt'),
	(275, '2015-08-13', 25, '2015-12', 'SO', 1221, 2, 0, 1, 1, 2655.00, 'Pc(s)', 2, 31, 0, 'Sales', NULL, '', 'ggt'),
	(276, '2015-08-14', 26, '2015-13', 'SO', 617, 1, 0, 1, 0, 1414.29, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(277, '2015-08-18', 27, '2015-14', 'SO', 1094, 5, 0, 1, 4, 880.00, 'Pc(s)', 2, 1, 0, 'Sales', NULL, '', 'ggt'),
	(278, '2015-08-20', 18, '2015-5', 'SO', 1375, 10, 0, 1, 9, 585.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(279, '2015-08-20', 18, '2015-5', 'SO', 1370, 44, 0, 2, 42, 960.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(280, '2015-08-20', 18, '2015-5', 'SO', 1364, 11, 0, 1, 10, 805.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(281, '2015-08-22', 28, '2015-15', 'SO', 314, 3, 0, 1, 2, 2420.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(282, '2015-08-22', 28, '2015-15', 'SO', 361, 3, 0, 1, 2, 2090.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(283, '2015-08-24', 37, '3', 'INV', 22, 11, 0, 1, 10, 294000.00, 'Unit(s)', 3, 3, 0, 'Sales', NULL, '', 'ggt'),
	(284, '2015-08-24', 19, '2015-6', 'SO', 799, 8, 0, 1, 7, 80.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(285, '2015-08-24', 30, '2015-17', 'SO', 1220, 2, 0, 1, 1, 3700.00, 'Pc(s)', 2, 31, 0, 'Sales', NULL, '', 'ggt'),
	(286, '2015-08-24', 29, '2015-16', 'SO', 811, 193, 0, 1, 192, 27.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(287, '2015-08-24', 29, '2015-16', 'SO', 796, 1, 0, 1, 0, 145.85, 'Pc(s)', 2, 41, 0, 'Sales', NULL, '', 'ggt'),
	(288, '2015-08-24', 29, '2015-16', 'SO', 793, 1, 0, 1, 0, 100.00, 'Pc(s)', 2, 41, 0, 'Sales', NULL, '', 'ggt'),
	(289, '2015-08-25', 20, '2015-7', 'SO', 1362, 12, 0, 1, 11, 182.00, 'Pc(s)', 7, 19, 0, 'Sales', NULL, '', 'ggt'),
	(290, '2015-08-26', 2018, '2015-3', 'RCV', 288, 0, 3, 0, 3, 2035.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(291, '2015-08-26', 2020, '2015-5', 'RCV', 791, 0, 1, 0, 1, 128.53, 'Pc(s)', 1, 25, 0, 'Receiving', NULL, '', 'jvd'),
	(292, '2015-08-26', 42, '2015-5', 'SVC', 1371, 34, 0, 2, 32, 655.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(293, '2015-08-26', 2018, '2015-3', 'RCV', 286, 0, 2, 0, 2, 1669.50, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(294, '2015-08-26', 42, '2015-5', 'SVC', 726, 17, 0, 1, 16, 55.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(295, '2015-08-26', 2018, '2015-3', 'RCV', 318, 2, 1, 0, 3, 385.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(296, '2015-08-26', 2019, '2015-4', 'RCV', 310, 1, 5, 0, 6, 644.00, 'Set(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(297, '2015-08-26', 2019, '2015-4', 'RCV', 312, 0, 2, 0, 2, 1085.00, 'Set(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(298, '2015-08-26', 2020, '2015-5', 'RCV', 790, 0, 1, 0, 1, 128.53, 'Pc(s)', 1, 25, 0, 'Receiving', NULL, '', 'jvd'),
	(299, '2015-08-26', 31, '2015-18', 'SO', 808, 1, 0, 1, 0, 145.85, 'Pc(s)', 2, 41, 0, 'Sales', NULL, '', 'ggt'),
	(300, '2015-08-26', 2018, '2015-3', 'RCV', 287, 0, 1, 0, 1, 7300.00, 'Set(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(301, '2015-08-26', 42, '2015-5', 'SVC', 525, 1, 0, 1, 0, 660.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(302, '2015-08-26', 2019, '2015-4', 'RCV', 311, 1, 5, 0, 6, 1085.00, 'Set(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(303, '2015-08-26', 2019, '2015-4', 'RCV', 313, 0, 5, 0, 5, 1085.00, 'Set(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(304, '2015-08-26', 2018, '2015-3', 'RCV', 319, 1, 1, 0, 2, 385.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(305, '2015-08-26', 31, '2015-18', 'SO', 811, 192, 0, 1, 191, 27.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(306, '2015-08-26', 31, '2015-18', 'SO', 756, 2, 0, 1, 1, 100.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(307, '2015-08-26', 2020, '2015-5', 'RCV', 306, 2, 1, 0, 3, 2415.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(308, '2015-08-26', 21, '2015-8', 'SO', 798, 3, 0, 1, 2, 80.00, 'Pc(s)', 1, 7, 0, 'Sales', NULL, '', 'ggt'),
	(309, '2015-08-26', 2018, '2015-3', 'RCV', 285, 0, 4, 0, 4, 2750.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(310, '2015-08-26', 2019, '2015-4', 'RCV', 443, 1, 5, 0, 6, 647.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(311, '2015-08-26', 2018, '2015-3', 'RCV', 317, 0, 5, 0, 5, 295.00, 'Pc(s)', 1, 2, 0, 'Receiving', NULL, '', 'jvd'),
	(312, '2015-08-27', 33, '2015-20', 'SO', 730, 1, 0, 1, 0, 1650.00, 'Pc(s)', 2, 40, 0, 'Sales', NULL, '', 'ggt'),
	(313, '2015-08-27', 38, '4', 'INV', 6, 1, 0, 1, 0, 839000.00, 'Unit(s)', 3, 22, 0, 'Sales', NULL, '', 'ggt'),
	(314, '2015-08-27', 43, '2015-6', 'SVC', 726, 16, 0, 1, 15, 55.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(315, '2015-08-27', 43, '2015-6', 'SVC', 1371, 32, 0, 2, 30, 655.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(316, '2015-08-27', 43, '2015-6', 'SVC', 537, 27, 0, 1, 26, 660.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(317, '2015-08-29', 44, '2015-7', 'SVC', 726, 15, 0, 1, 14, 55.00, 'Pc(s)', 1, 25, 0, 'Sales', NULL, '', 'ggt'),
	(318, '2015-08-29', 44, '2015-7', 'SVC', 537, 26, 0, 1, 25, 660.00, 'Pc(s)', 1, 2, 0, 'Sales', NULL, '', 'ggt'),
	(319, '2015-08-29', 34, '2015-21', 'SO', 1011, 1, 0, 1, 0, 605.00, 'Pc(s)', 2, 9, 0, 'Sales', NULL, '', 'ggt'),
	(320, '2015-08-29', 44, '2015-7', 'SVC', 1371, 30, 0, 2, 28, 655.00, 'Ltr(s)', 7, 26, 0, 'Sales', NULL, '', 'ggt'),
	(321, '2015-08-29', 34, '2015-21', 'SO', 1095, 8, 0, 1, 7, 880.00, 'Pc(s)', 2, 1, 0, 'Sales', NULL, '', 'ggt');
/*!40000 ALTER TABLE `tblitemhistory` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemlocation
DROP TABLE IF EXISTS `tblitemlocation`;
CREATE TABLE IF NOT EXISTS `tblitemlocation` (
  `idIL` int(10) NOT NULL,
  `pk` int(15) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `code` varchar(25) DEFAULT NULL,
  `location` int(10) DEFAULT NULL,
  `locationDetails` varchar(300) DEFAULT NULL,
  `owner` varchar(50) DEFAULT NULL,
  `status` varchar(100) DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL,
  `updatedBy` int(10) DEFAULT NULL,
  `dateUpdated` date DEFAULT NULL,
  `certifiedBy` int(10) DEFAULT NULL,
  PRIMARY KEY (`idIL`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemlocation: 0 rows
/*!40000 ALTER TABLE `tblitemlocation` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblitemlocation` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemmaintenance
DROP TABLE IF EXISTS `tblitemmaintenance`;
CREATE TABLE IF NOT EXISTS `tblitemmaintenance` (
  `idim` int(10) NOT NULL DEFAULT '0',
  `serviceNo` varchar(15) DEFAULT NULL,
  `idCustomer` int(15) NOT NULL,
  `dateReceived` date NOT NULL,
  `receivedBy` varchar(25) NOT NULL,
  `location` varchar(10) DEFAULT NULL,
  `services` int(3) NOT NULL,
  `details` text NOT NULL,
  `dateMaintained` date NOT NULL,
  `maintainedBy` varchar(50) NOT NULL,
  `serviceCost` double(15,2) NOT NULL,
  `itemStatus` varchar(30) NOT NULL,
  `itemRemarks` text NOT NULL,
  `checkedBy` varchar(50) NOT NULL,
  `dateReleased` date NOT NULL,
  `releasedBy` varchar(50) NOT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `idCustBike` int(15) DEFAULT NULL,
  PRIMARY KEY (`idim`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemmaintenance: 0 rows
/*!40000 ALTER TABLE `tblitemmaintenance` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblitemmaintenance` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemstatus
DROP TABLE IF EXISTS `tblitemstatus`;
CREATE TABLE IF NOT EXISTS `tblitemstatus` (
  `itemStatus` varchar(255) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemstatus: 3 rows
/*!40000 ALTER TABLE `tblitemstatus` DISABLE KEYS */;
INSERT INTO `tblitemstatus` (`itemStatus`) VALUES
	('BRAND NEW'),
	('PRE-OWNED'),
	('PHASE OUT');
/*!40000 ALTER TABLE `tblitemstatus` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemtax
DROP TABLE IF EXISTS `tblitemtax`;
CREATE TABLE IF NOT EXISTS `tblitemtax` (
  `idVat` int(1) NOT NULL DEFAULT '0',
  `tax` varchar(25) DEFAULT NULL,
  `percent` int(3) NOT NULL,
  PRIMARY KEY (`idVat`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemtax: 2 rows
/*!40000 ALTER TABLE `tblitemtax` DISABLE KEYS */;
INSERT INTO `tblitemtax` (`idVat`, `tax`, `percent`) VALUES
	(1, 'VAT', 12),
	(2, 'Non-VAT', 0);
/*!40000 ALTER TABLE `tblitemtax` ENABLE KEYS */;


-- Dumping structure for table invndc.tblitemvin
DROP TABLE IF EXISTS `tblitemvin`;
CREATE TABLE IF NOT EXISTS `tblitemvin` (
  `vin` varchar(100) DEFAULT NULL,
  `idSkRm` int(5) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblitemvin: 52 rows
/*!40000 ALTER TABLE `tblitemvin` DISABLE KEYS */;
INSERT INTO `tblitemvin` (`vin`, `idSkRm`) VALUES
	('A1', 1),
	('A2', 1),
	('A3', 1),
	('A4', 1),
	('A5', 1),
	('A6', 1),
	('A7', 1),
	('B1', 1),
	('B2', 1),
	('B3', 1),
	('B4', 1),
	('B5', 1),
	('B6', 1),
	('B7', 1),
	('B8', 1),
	('B9', 1),
	('B10', 1),
	('C1', 1),
	('C2', 1),
	('C3', 1),
	('C4', 1),
	('C5', 1),
	('C6', 1),
	('C7', 1),
	('C8', 1),
	('C9', 1),
	('C10', 1),
	('D1', 1),
	('E1', 1),
	('F1', 1),
	('F2', 1),
	('F3', 1),
	('F4', 1),
	('F5', 1),
	('G1', 1),
	('G2', 1),
	('G3', 1),
	('G4', 1),
	('G5', 1),
	('H1', 1),
	('H2', 1),
	('H3', 1),
	('H4', 1),
	('NDC-TMP', 4),
	('SHOW ROOM', 5),
	('SATELLITE PI', 6),
	('KUBO WAREHOUSE', 7),
	('STOCK ROOM', 8),
	('SATELLITE - PAGADIAN', 4),
	('STOCKROOM - MT PAGADIAN', 4),
	('SATELLITE - PAGADIAN', 4),
	('STOCKROOM - MT PAGADIAN', 4);
/*!40000 ALTER TABLE `tblitemvin` ENABLE KEYS */;


-- Dumping structure for table invndc.tbljoborder
DROP TABLE IF EXISTS `tbljoborder`;
CREATE TABLE IF NOT EXISTS `tbljoborder` (
  `idJO` int(15) NOT NULL DEFAULT '0',
  `idCustomer` int(8) DEFAULT NULL,
  `clNo` varchar(15) DEFAULT NULL,
  `dateStarted` date DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `idCustBike` int(15) DEFAULT NULL,
  `batteryNo` varchar(20) DEFAULT NULL,
  `odometer` varchar(20) DEFAULT NULL,
  `idBrand` int(3) DEFAULT NULL,
  `idModel` int(5) DEFAULT NULL,
  `service` varchar(1000) DEFAULT NULL,
  `idSrvcType` int(3) DEFAULT NULL,
  `code` varchar(20) DEFAULT NULL,
  `idSrvcTime` int(3) DEFAULT NULL,
  `idSrvCC` int(3) DEFAULT NULL,
  `minutes` int(5) DEFAULT NULL,
  `flatRate` double(12,2) DEFAULT NULL,
  `joRmrks` text,
  `joRcvdBy` varchar(30) DEFAULT NULL,
  `joPrprdBy` varchar(30) DEFAULT NULL,
  `joChckdBy` varchar(30) DEFAULT NULL,
  `joApprvdBy` varchar(30) DEFAULT NULL,
  `joid` varchar(25) DEFAULT NULL,
  `jeid` varchar(25) DEFAULT NULL,
  `dateFinished` date DEFAULT NULL,
  `timeIn` varchar(10) DEFAULT NULL,
  `timeOut` varchar(10) DEFAULT NULL,
  `jePrprdBy` varchar(30) DEFAULT NULL,
  `jeNotedBy` varchar(30) DEFAULT NULL,
  `jeApprvdBy` varchar(30) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `jeRmrks` varchar(1000) DEFAULT NULL,
  `soID` varchar(15) DEFAULT NULL,
  `salesInvc` varchar(15) DEFAULT NULL,
  `salesOr` varchar(15) DEFAULT NULL,
  `payMode` varchar(50) DEFAULT NULL,
  `checkNo` varchar(50) DEFAULT NULL,
  `partsTotal` double(15,2) DEFAULT NULL,
  `partDscnt` double(15,2) DEFAULT NULL,
  `srvcTotal` double(15,2) DEFAULT NULL,
  `srvcDscnt` double(15,2) DEFAULT NULL,
  `grandTotal` double(15,2) DEFAULT NULL,
  PRIMARY KEY (`idJO`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbljoborder: 59 rows
/*!40000 ALTER TABLE `tbljoborder` DISABLE KEYS */;
INSERT INTO `tbljoborder` (`idJO`, `idCustomer`, `clNo`, `dateStarted`, `idMtrbikes`, `idCustBike`, `batteryNo`, `odometer`, `idBrand`, `idModel`, `service`, `idSrvcType`, `code`, `idSrvcTime`, `idSrvCC`, `minutes`, `flatRate`, `joRmrks`, `joRcvdBy`, `joPrprdBy`, `joChckdBy`, `joApprvdBy`, `joid`, `jeid`, `dateFinished`, `timeIn`, `timeOut`, `jePrprdBy`, `jeNotedBy`, `jeApprvdBy`, `status`, `jeRmrks`, `soID`, `salesInvc`, `salesOr`, `payMode`, `checkNo`, `partsTotal`, `partDscnt`, `srvcTotal`, `srvcDscnt`, `grandTotal`) VALUES
	(1, 63, '02749', '2015-08-05', 0, 1, '', '1032.9', 0, 0, 'MiscellaneousPeriodic Maintenance', 0, '', 0, 0, 18, 1250.00, 'MiscellaneousPeriodic Maintenance', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Joseph V. Del Rosario Jr.', 'Jennifer P. Dantes', '2015-1', '2015-1', '2015-08-05', '1:30 PM', '4:30 PM', 'Annie Rose M. Deloso', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'sold', '', NULL, NULL, '1', 'Cash (Sales)', '0', 655.00, 0.00, 525.00, 0.00, 1180.00),
	(2, 87, '02760', '2015-08-12', 0, 2, '', '12243', 0, 6, 'MiscellaneousPeriodic MaintenancePeriodic MaintenanceMiscellaneousPeriodic MaintenanceMiscellaneousPeriodic MaintenanceMiscellaneousMiscellaneousPeriodic MaintenanceMiscellaneousPeriodic Maintenance', 0, '', 0, 0, 60, 1850.00, 'MiscellaneousPeriodic MaintenancePeriodic MaintenanceMiscellaneousPeriodic MaintenanceMiscellaneousPeriodic MaintenanceMiscellaneousMiscellaneousPeriodic MaintenanceMiscellaneousPeriodic Maintenance', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', '2015-2', '2015-3', '2015-08-12', '2:30 PM', '4:30 PM', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'sold', '', NULL, NULL, '2', 'Cash (Sales)', '0', 2545.00, 0.00, 2000.00, 0.00, 4545.00),
	(3, 23, '02766', '2015-08-22', 0, 3, '', '335.8', 8, 0, '', 0, '', 0, 0, 30, 1250.00, '', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', '2015-3', '2015-4', '2015-08-22', '01:00 PM', '3:45 PM', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'sold', '', NULL, NULL, '3', 'Cash (Sales)', '0', 0.00, 0.00, 775.00, 0.00, 775.00),
	(4, 94, '02770', '2015-08-26', 0, 4, '', '1131', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', '2015-4', '2015-5', '2015-08-26', '03:45 AM', '4:50 PM', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'Jennifer P. Dantes', 'sold', '', NULL, NULL, '4', 'Cash (Sales)', '0', 2025.00, 0.00, 1400.00, 0.00, 3425.00),
	(5, 14, '02771', '2015-08-27', 0, 5, '', '11050', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Jennifer P. Dantes', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', '2015-5', '2015-6', '2015-08-27', '01 PM', '02:05  PM', 'Jennifer P. Dantes', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '5', 'Cash (Sales)', '0', 2025.00, 0.00, 1400.00, 0.00, 3425.00),
	(6, 89, '02774', '2015-08-29', 0, 6, '', '1497', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Jennifer P. Dantes', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', '2015-6', '2015-7', '2015-08-29', '09 AM', '10:27 AM', 'Jennifer P. Dantes', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '6', 'Cash (Sales)', '0', 2025.00, 0.00, 1400.00, 0.00, 3425.00),
	(7, 39, '02781', '2015-09-18', 0, 7, 'M6C4R879939', '5,135', 0, 0, 'MiscellaneousMiscellaneousPeriodic Maintenance', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousMiscellaneousPeriodic Maintenance', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', '2015-7', '2015-8', '2015-09-18', '10:37 AM', '11:33 AM', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '7', 'Cash (Sales)', '0', 1370.00, 0.00, 1400.00, 0.00, 2770.00),
	(8, 83, '2775', '2015-09-01', 0, 8, '', '1 km', 0, 0, 'MiscellaneousCheck up for released brand new bike ', 0, '', 0, 0, 60, 1850.00, 'MiscellaneousCheck up for released brand new bike ', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-8', '2015-9', '2015-09-01', '03:45 PM', '04:50 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '8', 'Advertising', '0', 0.00, 0.00, 2000.00, 0.00, 2000.00),
	(9, 82, '2776', '2015-09-01', 0, 10, '', '1214.9', 0, 0, 'Periodic MaintenanceMiscellaneous', 0, '', 0, 0, 30, 1250.00, 'Periodic MaintenanceMiscellaneous', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-9', '2015-10', '2015-09-01', '1:27 PM', '02:15 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '9', 'Charge (Accounts Receivable)', '0', 655.00, 0.00, 775.00, 0.00, 1430.00),
	(10, 102, '2777', '2015-09-05', 0, 11, '', '353.9', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-10', '2015-11', '2015-09-05', '01 PM', '02:15 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '10', 'Charge (Accounts Receivable)', '0', 1325.00, 0.00, 1400.00, 0.00, 2725.00),
	(11, 104, '2778', '2015-09-10', 0, 14, '', '812', 0, 0, 'Installation Side Bags and BracketMiscellaneous', 0, '', 0, 0, 30, 1850.00, 'Installation Side Bags and BracketMiscellaneous', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Jenner  B. Moneba', 'Joseph V. Del Rosario Jr.', '2015-11', '2015-12', '2015-09-10', '09:40 AM', '03:45 PM', 'Girlie G. Tolosa', 'Jenner  B. Moneba', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '10', 'Charge (Accounts Receivable)', '0', 52175.00, 0.00, 1075.00, 0.00, 53250.00),
	(12, 69, '2779', '2015-09-10', 0, 15, '', '194', 0, 0, 'MiscellaneousCheck upBIKE WASH', 0, '', 0, 0, 180, 1250.00, 'MiscellaneousCheck upBIKE WASH', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Jenner  B. Moneba', 'Joseph V. Del Rosario Jr.', '2015-12', '2015-31', '2015-10-26', '02:17 PM', '11:26 AM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '31', 'Cash (Sales)', '0', 600.00, 0.00, 3940.00, 0.00, 4540.00),
	(13, 105, '2987', '2015-09-11', 0, 16, '', '2384', 0, 0, 'MiscellaneousPeriodic Maintenance', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousPeriodic Maintenance', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Jenner  B. Moneba', 'Joseph V. Del Rosario Jr.', '2015-13', '2015-14', '2015-09-11', '10 AM', '11 AM', 'Girlie G. Tolosa', 'Jenner  B. Moneba', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '10', 'Check', '0', 2025.00, 0.00, 1400.00, 0.00, 3425.00),
	(14, 83, '2782', '2015-09-21', 0, 17, '', '10 KM ', 0, 0, 'MiscellaneousCheck up for released brand new bike ', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousCheck up for released brand new bike ', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', '2015-14', '2015-15', '2015-09-21', '03:15 PM', '03:56 PM', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '13', 'Advertising', '0', 0.00, 0.00, 1400.00, 0.00, 1400.00),
	(15, 111, '2784', '2015-09-23', 0, 18, '', '3494', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', '2015-15', '2015-16', '2015-09-23', '01:10 PM', '02:10 PM', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '14', 'Cash (Sales)', '0', 1365.00, 0.00, 1400.00, 0.00, 2765.00),
	(16, 112, '2787', '2015-09-28', 0, 19, '', '4391', 0, 0, 'MiscellaneousPeriodic Maintenance', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousPeriodic Maintenance', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', '2015-16', '2015-17', '2015-09-28', '09:30 AM', '10:54 AM', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '15', 'Cash (Sales)', '0', 55.00, 0.00, 1400.00, 0.00, 1455.00),
	(17, 83, '2785', '2015-09-26', 0, 20, '', '1468', 0, 0, 'MiscellaneousCheck Front Fork Leak and Rear Tire Vulcate', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousCheck Front Fork Leak and Rear Tire Vulcate', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', '2015-17', '2015-18', '2015-09-26', '09 AM', '10:30 AM', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '16', 'Advertising', '0', 535.71, 0.00, 1400.00, 0.00, 1935.71),
	(18, 111, '02789', '2015-10-02', 0, 18, '', '3538', 8, 0, '', 0, '', 0, 0, 30, 1250.00, '', 'Joseph V. Del Rosario Jr.', 'Joseph V. Del Rosario Jr.', 'Norben Jay L.  Ruiz', 'Girlie G. Tolosa', '2015-18', '2015-19', '2015-10-02', '9:30 AM', '10:00 AM', 'Girlie G. Tolosa', 'Norben Jay L.  Ruiz', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '17', 'Cash (Sales)', '0', 0.00, 0.00, 775.00, 0.00, 775.00),
	(19, 16, '02790', '2015-10-06', 0, 24, '', '1543', 0, 0, 'MiscellaneousBIKE WASHPeriodic MaintenanceMiscellaneousBIKE WASHPeriodic MaintenanceMiscellaneousBIKE WASHPeriodic Maintenance', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousBIKE WASHPeriodic MaintenanceMiscellaneousBIKE WASHPeriodic MaintenanceMiscellaneousBIKE WASHPeriodic Maintenance', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-19', '2015-20', '2015-10-06', '4:47 PM', '5:47 PM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '18', 'Advertising Marketing Expense', '0', 1065.36, 0.00, 1440.00, 0.00, 2505.36),
	(20, 16, '02791', '2015-10-06', 0, 25, '', '10', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-20', '2015-21', '2015-10-06', '1:37 PM', '4:00 PM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '19', 'Advertising Marketing Expense', '0', 0.00, 0.00, 1400.00, 0.00, 1400.00),
	(21, 115, '02788', '2015-10-06', 0, 23, '', '6,328', 0, 0, 'MiscellaneousBIKE WASHPeriodic Maintenance/ Check up', 0, '', 0, 3, 96, 1250.00, 'MiscellaneousBIKE WASHPeriodic Maintenance/ Check up', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-21', '2015-22', '2015-11-14', '1:00 PM', '02:49 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '45', 'Check', '0', 6065.00, 0.00, 2190.00, 0.00, 8255.00),
	(39, 141, '2812', '2015-11-19', 0, 42, '', '2', 8, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', '2015-39', '43', '2015-11-19', ' ', '04:22 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '38', 'Marketing Expense', '0', 80.00, 0.00, 1617.36, 0.00, 1697.36),
	(22, 23, '02792', '2015-10-08', 0, 26, '', '2,074', 22, 10, '', 0, '', 0, 0, 90, 1850.00, '', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-22', '2015-23', '2015-10-10', '1:00 PM', '12:00 PM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '20', 'Check', '966', 1620.00, 0.00, 2925.00, 0.00, 4545.00),
	(23, 92, '02793', '2015-10-10', 0, 27, '', '1,173', 22, 10, '', 0, '', 0, 0, 60, 1850.00, '', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-23', '2015-24', '2015-10-10', '9:00 AM', '11:00 AM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '21', 'Cash (Sales)', '0', 2545.00, 0.00, 2000.00, 0.00, 4545.00),
	(24, 23, '02794', '2015-10-14', 0, 28, '', '12,331', 22, 9, 'Miscellaneous', 0, '', 0, 1, 30, 1850.00, 'Miscellaneous', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-24', '2015-25', '2015-10-14', '9:37 AM', '10:25 AM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '22', 'Cash (Sales)', '0', 0.00, 0.00, 1075.00, 0.00, 1075.00),
	(25, 123, '2795', '2015-10-14', 0, 29, '', '5019', 0, 0, 'MiscellaneousPeriodic Maintenance/ Check up', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousPeriodic Maintenance/ Check up', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-25', '2015-26', '2015-10-14', '2:40 PM', '03:40 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '23', 'Cash (Sales)', '0', 0.00, 0.00, 1400.00, 0.00, 1400.00),
	(26, 125, '2796', '2015-10-15', 0, 31, '', '6010', 0, 0, 'MiscellaneousPeriodic Maintenance/ Check up', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousPeriodic Maintenance/ Check up', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-26', '2015-29', '2015-10-15', '11:54 AM', '02:00 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '24', 'Cash (Sales)', '0', 1800.25, 0.00, 1400.00, 0.00, 3200.25),
	(27, 83, '2797', '2015-10-16', 0, 32, '', '10', 0, 0, 'MiscellaneousCheck up for released brand new bike ', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousCheck up for released brand new bike ', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-27', '2015-30', '2015-10-16', '03:00 PM', '04:40PM PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '25', 'Advertising Marketing Expense', '0', 0.00, 0.00, 1400.00, 0.00, 1400.00),
	(28, 83, '2798', '2015-10-17', 0, 33, '', '.04', 0, 0, 'MiscellaneousGasoline   Check Up for display Brand New Bike', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousGasoline   Check Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-28', '2015-32', '2015-10-19', '01:10 PM', '02:34 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '26', 'Marketing Expense', '0', 0.00, 0.00, 1600.00, 0.00, 1600.00),
	(29, 83, '2800', '2015-10-17', 0, 34, '', '0', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-29', '2015-33', '2015-10-19', '2:10 PM', '5:42 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '27', 'Marketing Expense', '0', 0.00, 0.00, 1600.00, 0.00, 1600.00),
	(30, 83, '2799', '2015-10-17', 0, 35, '', '0', 8, 0, '', 0, '', 0, 0, 60, 1850.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-30', '2015-34', '2015-10-19', '01:42 PM', '05:46 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '28', 'Marketing Expense', '0', 0.00, 0.00, 2000.00, 0.00, 2000.00),
	(31, 133, '02802', '2015-10-24', 0, 36, '', '10', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-31', '2015-35', '2015-10-24', '10:00 AM', '11:13 AM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '29', 'Marketing Expense', '0', 0.00, 0.00, 1550.00, 0.00, 1550.00),
	(32, 23, '2803', '2015-10-24', 0, 26, '', '2,074', 22, 10, '', 0, '', 0, 0, 30, 1850.00, '', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-32', '2015-36', '2015-10-24', '12:27 PM', '2:51 PM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '30', 'Cash (Sales)', '0', 0.00, 0.00, 1075.00, 0.00, 1075.00),
	(33, 83, '2804', '2015-10-26', 0, 38, '', '1KM', 8, 0, 'MiscellaneousGasoline   Check up for released brand new bike ', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousGasoline   Check up for released brand new bike ', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-33', '37', '2015-10-26', '2:16 PM', '2:43 PM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '32', 'Marketing Expense', '0', 0.00, 0.00, 1635.70, 0.00, 1635.70),
	(34, 83, '2805', '2015-10-26', 0, 39, '', '10KM', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', '2015-34', '38', '2015-10-26', '1:48 PM', '2:16 PM', 'Joseph V. Del Rosario Jr.', 'Leo Alfie A. Quipanes', 'Joseph V. Del Rosario Jr.', 'sold', '', NULL, NULL, '33', 'Marketing Expense', '0', 0.00, 0.00, 1588.56, 0.00, 1588.56),
	(35, 105, '2806', '2015-10-29', 0, 16, '', '5,908 ', 0, 0, 'MiscellaneousBIKE WASHCheck up / Service', 0, '', 0, 3, 150, 1250.00, 'MiscellaneousBIKE WASHCheck up / Service', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-35', '41', '2015-11-11', '10:47 AM', '03:35 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '36', 'Cash (Sales)', '0', 3499.00, 0.00, 3315.00, 0.00, 6814.00),
	(36, 112, '2807', '2015-10-31', 0, 19, '', '4789', 0, 0, 'MiscellaneousCHECK SPEEDOMETER MALFUNCTION', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousCHECK SPEEDOMETER MALFUNCTION', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-36', '42', '2015-11-12', '11 AM', '11:55 AM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '37', 'Cash (Sales)', '0', 2750.00, 0.00, 1400.00, 0.00, 4150.00),
	(37, 137, '2808', '2015-11-06', 0, 40, '', '0.4', 8, 0, '', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Arnie V. Layco', '2015-37', '39', '2015-11-06', '12:51 PM', '02:23 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Leo Alfie A. Quipanes', 'sold', '', NULL, NULL, '34', 'Marketing Expense', '0', 80.00, 0.00, 1500.00, 0.00, 1580.00),
	(38, 83, '2809', '2015-11-10', 0, 34, '', '10 km', 0, 0, 'MiscellaneousGasoline   Check up for released brand new bike ', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousGasoline   Check up for released brand new bike ', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-38', '40', '2015-11-10', '5:48 PM', '3:30 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '35', 'Marketing Expense', '0', 80.00, 0.00, 1534.22, 0.00, 1614.22),
	(40, 142, '2816', '2015-11-20', 0, 44, '', '1007', 8, 0, 'Regular Rate', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-40', '44', '2015-11-20', '1:00 PM', '03:36 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '39', 'Cash (Sales)', '0', 2025.00, 0.00, 1400.00, 0.00, 3425.00),
	(41, 83, '2815', '2015-11-20', 0, 45, '', '0', 0, 0, 'Free of Charge', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousGasoline   BikewashCheck Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-41', '45', '2015-11-20', '1:00 PM', '04:54 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '40', 'Marketing Expense', '0', 80.00, 0.00, 1573.02, 0.00, 1653.02),
	(42, 143, '02818', '2015-11-23', 0, 46, '', '186', 22, 6, 'Regular Rate', 0, '', 0, 0, 72, 1850.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-42', '46', '2015-11-23', '1 PM', '3:45 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '41', 'Cash (Sales)', '0', 2290.50, 162.00, 2370.00, 0.00, 4660.50),
	(43, 83, '02819', '2015-11-23', 0, 47, '', '4012', 22, 12, 'Free of Charge', 0, '', 0, 0, 60, 1850.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-43', '2015-47', '2015-11-23', '4:58 PM', '05:59 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '42', 'Marketing Expense', '0', 0.00, 0.00, 2040.00, 0.00, 2040.00),
	(44, 83, '2813', '2015-11-19', 0, 48, '', '0', 0, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousGasoline   BikewashCheck Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-44', '48', '2015-11-24', '10:49 AM', '11:11 AM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '43', 'Marketing Expense', '0', 0.00, 0.00, 1573.02, 0.00, 1573.02),
	(45, 83, '2810', '2015-11-24', 0, 49, '', '0.4KM', 8, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-45', '49', '2015-11-19', '02:46 PM', '02:19 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '54', 'Marketing Expense', '0', 80.00, 0.00, 1573.02, 0.00, 1653.02),
	(46, 83, '2814', '2015-11-24', 0, 50, '', '0', 8, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, 'Check Up for display Brand New BikeMiscellaneousGasoline   Bikewash', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-46', '50', '2015-11-24', '2:57 PM', '02:18 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Leo Alfie A. Quipanes', 'sold', '', NULL, NULL, '44', 'Marketing Expense', '0', 80.00, 0.00, 1571.07, 0.00, 1651.07),
	(47, 83, '2890', '2015-11-28', 0, 54, '', '5 KM ', 0, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousCheck Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-47', '51', '2015-11-16', '01:00 PM', '01:41 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '46', 'Marketing Expense', '0', 80.00, 0.00, 1400.00, 0.00, 1480.00),
	(48, 83, '2821', '2015-11-28', 0, 55, '', '0', 8, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-48', '52', '2015-11-28', '7 PM', '07:49 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '47', 'Marketing Expense', '0', 0.00, 0.00, 1400.00, 0.00, 1400.00),
	(49, 83, '2822', '2015-11-16', 0, 56, '', '4 KM ', 0, 0, 'Free of Charge', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousCheck Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-49', '53', '2015-11-16', '1:54 PM', '02:06 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '48', 'Marketing Expense', '0', 80.00, 0.00, 1400.00, 0.00, 1480.00),
	(50, 83, '2824', '2015-11-28', 0, 57, '', '9 KM ', 0, 0, 'Free of Charge', 0, '', 0, 3, 60, 1250.00, 'Check Up for display Brand New BikeMiscellaneous', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-50', '54', '2015-11-16', '4:14 PM', '03:21 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '49', 'Marketing Expense', '0', 80.00, 0.00, 1400.00, 0.00, 1480.00),
	(51, 83, '2825', '2015-11-16', 0, 58, '', '10 KM', 0, 0, 'Free of Charge', 0, '', 0, 3, 60, 1250.00, 'MiscellaneousCheck Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-51', '55', '2015-11-16', '7:46 PM', '08:38 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '50', 'Marketing Expense', '0', 0.00, 0.00, 1400.00, 0.00, 1400.00),
	(52, 83, '2825', '2015-11-16', 0, 59, '', '8 KM ', 8, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-52', '56', '2015-11-16', '3:25 PM', '4:51 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '52', 'Marketing Expense', '0', 80.00, 0.00, 1400.00, 0.00, 1480.00),
	(53, 83, '2827', '2015-11-28', 0, 60, '', '10 KM', 8, 0, 'Free of Charge', 0, '', 0, 0, 60, 1250.00, 'MiscellaneousCheck Up for display Brand New Bike', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-53', '57', '2015-11-28', '09 AM', '10:59 AM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '51', 'Marketing Expense', '0', 0.00, 0.00, 1531.07, 0.00, 1531.07),
	(54, 122, '2828', '2015-12-09', 0, 61, '', '10346', 8, 0, 'Regular Rate', 0, '', 0, 3, 48, 1250.00, '', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-54', '58', '2015-12-09', '11:20 AM', '01:58 PM', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Girlie G. Tolosa', 'sold', '', NULL, NULL, '53', 'Cash (Sales)', '0', 9072.50, 252.00, 6150.00, 0.00, 15222.50),
	(55, 153, '2829', '2015-12-16', 0, 62, '', '4094', 0, 0, 'Regular Rate', 0, '', 0, 0, 78, 1250.00, 'MiscellaneousCHECK UP - ENGINE OVERHEATING', 'Girlie G. Tolosa', 'Girlie G. Tolosa', 'Leo Alfie A. Quipanes', 'Jenner  B. Moneba', '2015-55', '2015-59', '2015-12-16', '09:39 AM', '11:21 AM', '', 'Leo Alfie Quipanes', 'Girlie Tolosa', 'sold', '', NULL, NULL, '55', 'Cash  - Service', '', 585.00, 0.00, 1775.00, 0.00, 2360.00),
	(56, 154, '2831', '2015-12-17', 0, 63, '', '358 KM', 0, 0, 'Regular Rate', 0, '', 0, 3, 30, 1250.00, 'MiscellaneousInstall Aftermarket Accessories', 'Girlie Tolosa', 'Girlie G. Tolosa', 'Leo Alfie Quipanes', 'Iris  Trinidad', '2015-56', '2015-60', '2015-12-17', '04:12 PM', '05:42 PM', 'Girlie Tolosa', 'Leo Alfie Quipanes', 'Iris  Trinidad', 'sold', '', NULL, NULL, '56', 'Cash  - Service', '', 10324.00, 2581.00, 775.00, 0.00, 11099.00),
	(57, 63, '02830', '2015-12-18', 0, 65, '', '1423 ', 8, 0, 'Regular Rate', 0, '', 0, 0, 0, 1250.00, '', 'Girlie Tolosa', 'Girlie G. Tolosa', 'Leo Alfie Quipanes', 'Iris  Trinidad', '2015-57', '0', '0000-00-00', '05:43 PM', '00:00 HH', NULL, NULL, NULL, 'for JE', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(58, 153, '2832', '2015-12-18', 0, 66, '', '4133', 8, 0, 'Regular Rate', 0, '', 0, 3, 18, 1250.00, 'MiscellaneousCheck up / Radiator Fan Mulfunction & Replace Radiator Fan ', 'Girlie Tolosa', 'Girlie G. Tolosa', 'Leo Alfie Quipanes', 'Iris  Trinidad', '2015-58', '2015-61', '2015-12-18', '1:02 PM', '01:22 PM', '', 'Leo Alfie Quipanes', 'Iris  Trinidad', 'sold', '', NULL, NULL, '57', 'Cash  - Service', '', 5192.00, 1298.00, 525.00, 0.00, 5717.00),
	(59, 122, '2833', '2015-12-19', 0, 61, '', '11121', 8, 0, 'Regular Rate', 0, '', 0, 0, 0, 1250.00, '', 'Girlie Tolosa', 'Girlie G. Tolosa', 'Leo Alfie Quipanes', 'Iris  Trinidad', '2015-59', '0', '0000-00-00', '11:41 AM', '00:00 HH', NULL, NULL, NULL, 'for JE', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
/*!40000 ALTER TABLE `tbljoborder` ENABLE KEYS */;


-- Dumping structure for table invndc.tbljoitems
DROP TABLE IF EXISTS `tbljoitems`;
CREATE TABLE IF NOT EXISTS `tbljoitems` (
  `idJOI` int(15) NOT NULL DEFAULT '0',
  `idItem` int(15) DEFAULT NULL,
  `idSrvcItem` int(15) DEFAULT NULL,
  `unit` varchar(10) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `unitPrice` double(12,2) DEFAULT NULL,
  `discount` int(3) DEFAULT NULL,
  `amntDscnt` double(15,2) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `remarks` text,
  `idJO` int(15) DEFAULT NULL,
  `joID` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idJOI`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbljoitems: 75 rows
/*!40000 ALTER TABLE `tbljoitems` DISABLE KEYS */;
INSERT INTO `tbljoitems` (`idJOI`, `idItem`, `idSrvcItem`, `unit`, `qty`, `unitPrice`, `discount`, `amntDscnt`, `amount`, `status`, `remarks`, `idJO`, `joID`) VALUES
	(1, 1371, 0, 'Ltr(s)', 1, 655.00, 0, NULL, 655.00, 'sold', 'job order', 1, '2015-1'),
	(2, 1351, 0, 'Ltr(s)', 3, 540.00, 0, NULL, 1620.00, 'sold', 'job order', 2, '2015-2'),
	(3, 155, 0, 'Pc(s)', 1, 925.00, 0, NULL, 925.00, 'sold', 'job order', 2, '2015-2'),
	(4, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'Pending', 'job order', 4, '2015-4'),
	(5, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'Pending', 'job order', 4, '2015-4'),
	(6, 525, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'Pending', 'job order', 4, '2015-4'),
	(7, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'sold', 'job order', 5, '2015-5'),
	(8, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'sold', 'job order', 5, '2015-5'),
	(9, 537, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'sold', 'job order', 5, '2015-5'),
	(10, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'sold', 'job order', 6, '2015-6'),
	(11, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'sold', 'job order', 6, '2015-6'),
	(12, 537, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'sold', 'job order', 6, '2015-6'),
	(13, 1371, 0, 'Ltr(s)', 1, 655.00, 0, NULL, 655.00, 'Pending', 'job order', 7, '2015-7'),
	(14, 537, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'Pending', 'job order', 7, '2015-7'),
	(15, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'Pending', 'job order', 7, '2015-7'),
	(16, 1371, 0, 'Ltr(s)', 1, 655.00, 0, NULL, 655.00, 'Pending', 'job order', 9, '2015-9'),
	(18, 1372, 0, 'Ltr(s)', 1, 670.00, 0, NULL, 670.00, 'Pending', 'job order', 10, '2015-10'),
	(17, 1376, 0, 'Ltr(s)', 1, 655.00, 0, NULL, 655.00, 'Pending', 'job order', 10, '2015-10'),
	(19, 1382, 0, 'Set(s)', 1, 52175.00, 0, NULL, 52175.00, 'Pending', 'job order', 11, '2015-11'),
	(20, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'Pending', 'job order', 13, '2015-13'),
	(22, 537, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'Pending', 'job order', 13, '2015-13'),
	(21, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'Pending', 'job order', 13, '2015-13'),
	(24, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'Pending', 'job order', 15, '2015-15'),
	(23, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'Pending', 'job order', 15, '2015-15'),
	(25, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'Pending', 'job order', 16, '2015-16'),
	(26, 441, 0, 'Pc(s)', 1, 535.71, 0, NULL, 535.71, 'Pending', 'job order', 17, '2015-17'),
	(30, 1371, 0, 'Ltr(s)', 2, 377.68, 0, NULL, 755.36, 'Pending', 'job order', 19, '2015-19'),
	(32, 537, 0, 'Pc(s)', 1, 295.00, 0, NULL, 295.00, 'Pending', 'job order', 19, '2015-19'),
	(31, 726, 0, 'Pc(s)', 1, 15.00, 0, NULL, 15.00, 'Pending', 'job order', 19, '2015-19'),
	(38, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'sold', 'job order', 21, '2015-21'),
	(40, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'sold', 'job order', 21, '2015-21'),
	(33, 351, 0, 'Pc(s)', 1, 1430.00, 0, NULL, 1430.00, 'sold', 'job order', 21, '2015-21'),
	(39, 1364, 0, 'Ltr(s)', 1, 805.00, 0, NULL, 805.00, 'sold', 'job order', 21, '2015-21'),
	(37, 537, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'sold', 'job order', 21, '2015-21'),
	(35, 1388, 0, 'Pc(s)', 1, 125.00, 0, NULL, 125.00, 'sold', 'job order', 21, '2015-21'),
	(36, 1397, 0, 'Pc(s)', 1, 250.00, 0, NULL, 250.00, 'sold', 'job order', 21, '2015-21'),
	(34, 415, 0, 'Pc(s)', 1, 1430.00, 0, NULL, 1430.00, 'sold', 'job order', 21, '2015-21'),
	(41, 1351, 0, 'Ltr(s)', 3, 540.00, 0, NULL, 1620.00, 'Pending', 'job order', 22, '2015-22'),
	(43, 1351, 0, 'Ltr(s)', 3, 540.00, 0, NULL, 1620.00, 'Pending', 'job order', 23, '2015-23'),
	(42, 155, 0, 'Pc(s)', 1, 925.00, 0, NULL, 925.00, 'Pending', 'job order', 23, '2015-23'),
	(45, 764, 0, 'Pc(s)', 1, 555.00, 5, NULL, 527.25, 'sold', 'job order', 26, '2015-26'),
	(44, 1377, 0, 'Ltr(s)', 2, 670.00, 5, NULL, 1273.00, 'sold', 'job order', 26, '2015-26'),
	(46, 1406, 0, 'Pc(s)', 1, 600.00, 0, NULL, 600.00, 'Pending', 'job order', 12, '2015-12'),
	(52, 1371, 0, 'Ltr(s)', 1, 655.00, 0, NULL, 655.00, 'sold', 'job order', 35, '2015-35'),
	(49, 1368, 0, 'Ltr(s)', 1, 809.00, 0, NULL, 809.00, 'sold', 'job order', 35, '2015-35'),
	(53, 1420, 0, 'Pc(s)', 1, 110.00, 0, NULL, 110.00, 'sold', 'job order', 35, '2015-35'),
	(50, 1381, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 37, '2015-37'),
	(51, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 38, '2015-38'),
	(47, 441, 0, 'Pc(s)', 1, 825.00, 0, NULL, 825.00, 'sold', 'job order', 35, '2015-35'),
	(48, 530, 0, 'Pc(s)', 1, 1100.00, 0, NULL, 1100.00, 'sold', 'job order', 35, '2015-35'),
	(54, 1418, 0, 'Pc(s)', 1, 2750.00, 0, NULL, 2750.00, 'sold', 'job order', 36, '2015-36'),
	(55, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 39, '2015-39'),
	(58, 1371, 0, 'Ltr(s)', 2, 655.00, 0, NULL, 1310.00, 'sold', 'job order', 40, '2015-40'),
	(57, 726, 0, 'Pc(s)', 1, 55.00, 0, NULL, 55.00, 'sold', 'job order', 40, '2015-40'),
	(56, 537, 0, 'Pc(s)', 1, 660.00, 0, NULL, 660.00, 'sold', 'job order', 40, '2015-40'),
	(59, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 41, '2015-41'),
	(61, 1351, 0, 'Ltr(s)', 3, 540.00, 10, NULL, 1458.00, 'sold', 'job order', 42, '2015-42'),
	(60, 155, 0, 'Pc(s)', 1, 925.00, 10, NULL, 832.50, 'sold', 'job order', 42, '2015-42'),
	(62, 1381, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 45, '2015-45'),
	(63, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 46, '2015-46'),
	(64, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 47, '2015-47'),
	(65, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 49, '2015-49'),
	(66, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 50, '2015-50'),
	(67, 799, 0, 'Pc(s)', 1, 80.00, 0, NULL, 80.00, 'sold', 'job order', 52, '2015-52'),
	(68, 314, 0, 'Pc(s)', 1, 2420.00, 5, NULL, 2299.00, 'sold', 'job order', 54, '2015-54'),
	(70, 334, 0, 'Set(s)', 1, 5040.00, 5, NULL, 4788.00, 'sold', 'job order', 54, '2015-54'),
	(69, 1450, 0, 'Pc(s)', 1, 2090.00, 5, NULL, 1985.50, 'sold', 'job order', 54, '2015-54'),
	(71, 1375, 0, 'Ltr(s)', 1, 585.00, 0, NULL, 585.00, 'sold', 'job order', 55, '2015-55'),
	(72, 1433, 0, 'Pc(s)', 1, 2420.00, 20, 484.00, 1936.00, 'sold', 'job order', 56, '2015-56'),
	(74, 854, 0, 'Set(s)', 1, 5445.00, 20, 1089.00, 4356.00, 'sold', 'job order', 56, '2015-56'),
	(73, 334, 0, 'Set(s)', 1, 5040.00, 20, 1008.00, 4032.00, 'sold', 'job order', 56, '2015-56'),
	(75, 291, 0, 'Set(s)', 1, 6490.00, 20, 1298.00, 5192.00, 'sold', 'job order', 58, '2015-58'),
	(76, 1371, 0, 'Ltr(s)', 1, 655.00, 0, 0.00, 655.00, 'Pending', 'job order', 59, '2015-59'),
	(77, 537, 0, 'Pc(s)', 1, 660.00, 0, 0.00, 660.00, 'Pending', 'job order', 59, '2015-59'),
	(78, 726, 0, 'Pc(s)', 1, 55.00, 0, 0.00, 55.00, 'Pending', 'job order', 59, '2015-59');
/*!40000 ALTER TABLE `tbljoitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tbljoservices
DROP TABLE IF EXISTS `tbljoservices`;
CREATE TABLE IF NOT EXISTS `tbljoservices` (
  `id` int(10) NOT NULL AUTO_INCREMENT,
  `idJO` int(15) DEFAULT NULL,
  `joID` varchar(15) DEFAULT NULL,
  `idSrvcTime` int(10) DEFAULT NULL,
  `idSrvcOther` int(10) DEFAULT NULL,
  `services` varchar(1000) DEFAULT NULL,
  `minutes` decimal(10,2) DEFAULT NULL,
  `qty` int(5) DEFAULT NULL,
  `charge` double(12,2) DEFAULT NULL,
  `bikeBrand` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=146 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbljoservices: 142 rows
/*!40000 ALTER TABLE `tbljoservices` DISABLE KEYS */;
INSERT INTO `tbljoservices` (`id`, `idJO`, `joID`, `idSrvcTime`, `idSrvcOther`, `services`, `minutes`, `qty`, `charge`, `bikeBrand`) VALUES
	(2, 1, '2015-1', 0, 0, 'Periodic Maintenance', 18.00, 0, 0.00, 'Others'),
	(1, 1, '2015-1', 0, 0, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(4, 2, '2015-2', 0, 0, 'Periodic Maintenance', 60.00, 1, 0.00, 'DUCATI'),
	(3, 2, '2015-2', 0, 0, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(5, 3, '2015-3', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(6, 3, '2015-3', 0, 1, 'Remove & Installation Exhaust Muffler, Lubricate & adjust chain', 30.00, 1, 0.00, 'NON-DUCATI'),
	(7, 4, '2015-4', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(8, 4, '2015-4', 0, 1, 'Change Oil, Change Filter, replace o-ring, lubricate chain, clean air filter, check tire', 60.00, 1, 0.00, 'NON-DUCATI'),
	(9, 5, '2015-5', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(10, 5, '2015-5', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, 'NON-DUCATI'),
	(11, 6, '2015-6', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(12, 6, '2015-6', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, 'NON-DUCATI'),
	(14, 7, '2015-7', 0, 0, 'Periodic Maintenance', 60.00, 1, 0.00, 'Others'),
	(13, 7, '2015-7', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(16, 8, '2015-8', 0, 0, 'Check up for released brand new bike ', 60.00, 0, 0.00, ''),
	(15, 8, '2015-8', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, ''),
	(18, 9, '2015-9', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(17, 9, '2015-9', 0, 0, 'Periodic Maintenance', 30.00, 1, 0.00, 'Others'),
	(19, 10, '2015-10', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(20, 10, '2015-10', 0, 1, 'CHECK UP LOOSE CONTACT ELECTRICAL WIRING', 60.00, 1, 0.00, 'NON-DUCATI'),
	(21, 11, '2015-11', 0, 1, 'Installation Side Bags and Bracket', 30.00, 1, 0.00, 'Others'),
	(22, 11, '2015-11', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(23, 12, '2015-12', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(24, 12, '2015-12', 0, 1, 'Check up', 180.00, 1, 0.00, 'NON-DUCATI'),
	(26, 13, '2015-13', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, 'Others'),
	(25, 13, '2015-13', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(28, 14, '2015-14', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'Others'),
	(27, 14, '2015-14', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(29, 15, '2015-15', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(30, 15, '2015-15', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, 'NON-DUCATI'),
	(36, 16, '2015-16', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, ''),
	(35, 16, '2015-16', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, ''),
	(34, 17, '2015-17', 0, 1, 'Check Front Fork Leak and Rear Tire Vulcate', 60.00, 1, 0.00, 'Others'),
	(33, 17, '2015-17', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'Others'),
	(37, 18, '2015-18', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(38, 18, '2015-18', 0, 1, 'Installation stock REAR SET', 30.00, 1, 0.00, 'NON-DUCATI'),
	(39, 19, '2015-19', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(40, 19, '2015-19', 0, 1, 'BIKE WASH', 0.00, 1, 40.00, 'NON-DUCATI'),
	(41, 19, '2015-19', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, 'NON-DUCATI'),
	(42, 20, '2015-20', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(43, 20, '2015-20', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(44, 21, '2015-21', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(45, 21, '2015-21', 0, 1, 'BIKE WASH', 0.00, 1, 40.00, 'NON-DUCATI'),
	(46, 21, '2015-21', 0, 1, 'Periodic Maintenance/ Check up', 96.00, 1, 0.00, 'NON-DUCATI'),
	(47, 22, '2015-22', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(48, 22, '2015-22', 0, 1, 'Periodic Maintenance', 90.00, 1, 0.00, 'DUCATI'),
	(49, 23, '2015-23', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(50, 23, '2015-23', 0, 1, 'Periodic Maintenance', 60.00, 1, 0.00, 'DUCATI'),
	(51, 24, '2015-24', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(52, 24, '2015-24', 0, 1, 'Check up and replace front brake', 30.00, 1, 0.00, 'DUCATI'),
	(53, 25, '2015-25', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(54, 25, '2015-25', 0, 1, 'Periodic Maintenance/ Check up', 60.00, 1, 0.00, 'NON-DUCATI'),
	(55, 26, '2015-26', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(56, 26, '2015-26', 0, 1, 'Periodic Maintenance/ Check up', 60.00, 1, 0.00, 'NON-DUCATI'),
	(57, 27, '2015-27', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(58, 27, '2015-27', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(59, 12, '2015-12', 0, 0, 'BIKE WASH', 0.00, 1, 40.00, 'NON-DUCATI'),
	(60, 28, '2015-28', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(61, 28, '2015-28', 0, 1, 'Gasoline   ', 0.00, 1, 200.00, 'NON-DUCATI'),
	(62, 28, '2015-28', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(63, 29, '2015-29', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(64, 29, '2015-29', 0, 1, 'Gasoline   ', 0.00, 1, 200.00, 'NON-DUCATI'),
	(65, 29, '2015-29', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(66, 30, '2015-30', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(67, 30, '2015-30', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(68, 31, '2015-31', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(69, 31, '2015-31', 0, 1, 'Gasoline   ', 0.00, 1, 150.00, 'NON-DUCATI'),
	(70, 31, '2015-31', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(71, 32, '2015-32', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(72, 32, '2015-32', 0, 1, 'Instrument Accessories Exhaust Muffler/ Radiator Grill and Engine Mud Guard', 30.00, 1, 0.00, 'DUCATI'),
	(73, 33, '2015-33', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(74, 33, '2015-33', 0, 1, 'Gasoline   ', 0.00, 1, 235.70, 'NON-DUCATI'),
	(75, 33, '2015-33', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(76, 34, '2015-34', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(77, 34, '2015-34', 0, 1, 'Gasoline   ', 0.00, 1, 188.56, 'NON-DUCATI'),
	(78, 34, '2015-34', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(79, 35, '2015-35', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(80, 35, '2015-35', 0, 1, 'BIKE WASH', 0.00, 1, 40.00, 'NON-DUCATI'),
	(90, 35, '2015-35', 0, 1, 'Check up / Service', 150.00, 1, 0.00, 'NON-DUCATI'),
	(82, 36, '2015-36', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(83, 36, '2015-36', 0, 1, 'CHECK SPEEDOMETER MALFUNCTION', 60.00, 1, 0.00, 'NON-DUCATI'),
	(84, 37, '2015-37', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(85, 37, '2015-37', 0, 1, 'Gasoline   ', 0.00, 1, 100.00, 'NON-DUCATI'),
	(86, 37, '2015-37', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(87, 38, '2015-38', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(88, 38, '2015-38', 0, 1, 'Gasoline   ', 0.00, 1, 134.22, 'NON-DUCATI'),
	(89, 38, '2015-38', 0, 1, 'Check up for released brand new bike ', 60.00, 1, 0.00, 'NON-DUCATI'),
	(91, 39, '2015-39', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(92, 39, '2015-39', 0, 1, 'Bikewash', 0.00, 1, 40.00, 'NON-DUCATI'),
	(93, 39, '2015-39', 0, 1, 'Gasoline   ', 0.00, 1, 177.36, 'NON-DUCATI'),
	(94, 39, '2015-39', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(95, 40, '2015-40', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(96, 40, '2015-40', 0, 1, 'Periodic Maintenance/ Check up', 60.00, 1, 0.00, 'NON-DUCATI'),
	(97, 41, '2015-41', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(98, 41, '2015-41', 0, 1, 'Gasoline   ', 0.00, 1, 133.02, 'NON-DUCATI'),
	(99, 41, '2015-41', 0, 1, 'Bikewash', 0.00, 1, 40.00, 'NON-DUCATI'),
	(100, 41, '2015-41', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(101, 42, '2015-42', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(102, 42, '2015-42', 0, 1, 'Check up / First Periodic Maintenance', 72.00, 1, 0.00, 'DUCATI'),
	(103, 43, '2015-43', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'DUCATI'),
	(104, 43, '2015-43', 0, 1, 'Bikewash', 0.00, 1, 40.00, 'DUCATI'),
	(105, 43, '2015-43', 0, 1, 'Check up for display Demobike', 60.00, 1, 40.00, 'DUCATI'),
	(106, 44, '2015-44', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(107, 44, '2015-44', 0, 1, 'Gasoline   ', 0.00, 1, 133.02, 'NON-DUCATI'),
	(108, 44, '2015-44', 0, 1, 'Bikewash', 0.00, 1, 40.00, 'NON-DUCATI'),
	(109, 44, '2015-44', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(110, 45, '2015-45', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(111, 45, '2015-45', 0, 1, 'Gasoline   ', 0.00, 1, 133.02, 'NON-DUCATI'),
	(112, 45, '2015-45', 0, 1, 'Bikewash', 0.00, 1, 40.00, 'NON-DUCATI'),
	(113, 45, '2015-45', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(114, 46, '2015-46', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(115, 46, '2015-46', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(116, 46, '2015-46', 0, 1, 'Gasoline   ', 0.00, 1, 131.07, 'NON-DUCATI'),
	(117, 46, '2015-46', 0, 1, 'Bikewash', 0.00, 1, 40.00, 'NON-DUCATI'),
	(118, 47, '2015-47', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(119, 47, '2015-47', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(120, 48, '2015-48', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(121, 48, '2015-48', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(122, 49, '2015-49', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(123, 49, '2015-49', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(124, 50, '2015-50', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(125, 50, '2015-50', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(126, 51, '2015-51', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(127, 51, '2015-51', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(128, 52, '2015-52', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(129, 52, '2015-52', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(130, 53, '2015-53', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(131, 53, '2015-53', 0, 1, 'Check Up for display Brand New Bike', 60.00, 1, 0.00, 'NON-DUCATI'),
	(132, 53, '2015-53', 0, 1, 'Gasoline   ', 0.00, 1, 131.07, 'NON-DUCATI'),
	(133, 54, '2015-54', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(134, 54, '2015-54', 0, 1, 'Replace Clutch Cable/Install Frame Slider and Radiator Grill', 48.00, 1, 0.00, 'NON-DUCATI'),
	(135, 54, '2015-54', 0, 1, 'Service Acceptance Fee', 0.00, 1, 5000.00, 'NON-DUCATI'),
	(136, 55, '2015-55', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(137, 55, '2015-55', 0, 1, 'CHECK UP - ENGINE OVERHEATING', 78.00, 1, 0.00, 'NON-DUCATI'),
	(138, 56, '2015-56 ', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(139, 56, '2015-56 ', 0, 1, 'Install Aftermarket Accessories', 30.00, 1, 0.00, 'NON-DUCATI'),
	(140, 57, '2015-57', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(141, 57, '2015-57', 0, 1, 'Check up & Troubleshoot Engine wont start', 60.00, 1, 0.00, 'NON-DUCATI'),
	(142, 58, '2015-58', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(143, 58, '2015-58', 0, 1, 'Check up / Radiator Fan Mulfunction & Replace Radiator Fan ', 18.00, 1, 0.00, 'NON-DUCATI'),
	(144, 59, '2015-59', 0, 1, 'Miscellaneous', 0.00, 1, 150.00, 'NON-DUCATI'),
	(145, 59, '2015-59', 0, 1, 'Periodic Maintenance/ Check up', 60.00, 1, 0.00, 'NON-DUCATI');
/*!40000 ALTER TABLE `tbljoservices` ENABLE KEYS */;


-- Dumping structure for table invndc.tbllocation
DROP TABLE IF EXISTS `tbllocation`;
CREATE TABLE IF NOT EXISTS `tbllocation` (
  `idLocation` int(3) NOT NULL DEFAULT '0',
  `locationCode` varchar(10) DEFAULT NULL,
  `Location` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`idLocation`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbllocation: 4 rows
/*!40000 ALTER TABLE `tbllocation` DISABLE KEYS */;
INSERT INTO `tbllocation` (`idLocation`, `locationCode`, `Location`) VALUES
	(1, 'CDO', 'Cagayan de Oro City'),
	(2, 'DVO', 'Davao City'),
	(3, 'ZBO', 'Zamboanga City'),
	(4, 'BTU', 'Butuan City');
/*!40000 ALTER TABLE `tbllocation` ENABLE KEYS */;


-- Dumping structure for table invndc.tblmotorbikes
DROP TABLE IF EXISTS `tblmotorbikes`;
CREATE TABLE IF NOT EXISTS `tblmotorbikes` (
  `idMtrbikes` int(15) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `model` varchar(100) DEFAULT NULL,
  `yearMake` int(4) DEFAULT NULL,
  `color` varchar(30) DEFAULT NULL,
  `chassisNo` varchar(80) DEFAULT NULL,
  `plateNo` varchar(30) DEFAULT NULL,
  `engineNo` varchar(30) DEFAULT NULL,
  `orcrNo` varchar(30) DEFAULT NULL,
  `ccDisp` varchar(100) DEFAULT NULL,
  `vin` varchar(30) DEFAULT NULL,
  `insurance` varchar(20) DEFAULT NULL,
  `otherInsur` varchar(20) DEFAULT NULL,
  `dateExpiry` date DEFAULT NULL,
  `dateAdded` date DEFAULT NULL,
  `dateUpdated` date DEFAULT NULL,
  `type` varchar(30) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `remarks` text,
  `stockLctn` varchar(30) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblmotorbikes: 42 rows
/*!40000 ALTER TABLE `tblmotorbikes` DISABLE KEYS */;
INSERT INTO `tblmotorbikes` (`idMtrbikes`, `idItem`, `model`, `yearMake`, `color`, `chassisNo`, `plateNo`, `engineNo`, `orcrNo`, `ccDisp`, `vin`, `insurance`, `otherInsur`, `dateExpiry`, `dateAdded`, `dateUpdated`, `type`, `status`, `remarks`, `stockLctn`) VALUES
	(1, 13, 'KTM RC 200 NON ABS', 2015, 'BLACK', '*VBKJYC401FC006257', 'NONE', '4-906*01475*', '', '200', '', '', '', '0000-00-00', '0000-00-00', '0000-00-00', '', 'sold', 'Invoice 1', ''),
	(2, 24, 'Italjet Formula 125', 2015, 'Tricolore', '*ZJTFRBSE0BL500245', 'none', 'LJ1P52QMI*15013737', '', '125', '', '', '', '0000-00-00', '0000-00-00', '0000-00-00', '', 'sold', 'Invoice 2', ''),
	(3, 22, 'KTM DUKE 390 ABS', 2014, ' Black', '*VBKJGJ406EC226869*', 'NONE', '4-902*12767*', '', '390', '', '', '', '0000-00-00', '0000-00-00', '0000-00-00', '', 'sold', 'Invoice 3', ''),
	(4, 6, 'Hyperstrada 821 ', 2015, 'Red', 'ML0B100AAET001328', 'none', 'ZDM821W4C*001335', '', '821', '', '', '', '0000-00-00', '0000-00-00', '0000-00-00', '', 'sold', 'Invoice 4', ''),
	(5, 14, 'KTM RC 390', 2015, 'WHITE', 'VBKJYJ40XFC210964', '', '5-902*06077*', '', '390', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'sold', 'Invoice 23', ''),
	(6, 14, 'KTM RC 390', 2015, 'WHITE', 'VBKJYJ401FC210965', '', '5-902*06109*', '', '390', '', '', '', '0000-00-00', '2015-07-31', '2015-07-31', '', 'sold', 'Invoice 24', ''),
	(7, 17, 'KTM DUKE 200', 2014, 'ORANGE', '*VBKJUC409EC023656*', '', '4-906*54818*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'sold', 'Invoice 35', ''),
	(8, 17, 'KTM DUKE 200', 2014, 'ORANGE', '*VBKJUC409EC020949*', '', '4-906*52599*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'sold', 'Invoice 20', ''),
	(9, 17, 'KTM DUKE 200', 2014, 'ORANGE', '*VBKJUC405EC020950*', '', '4-906*52602*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'sold', 'Invoice 18', ''),
	(10, 17, 'KTM DUKE 200', 2014, 'WHITE', '*VBKJUC408EC027696*', '', '4-906*58276*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'BRAND NEW', '', ''),
	(11, 13, 'KTM RC 200', 2015, 'BLACK', 'VBKJYC401FC006274', 'LC 61998', '5-906*01418*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '2015-07-31', '', 'DEMO', '', ''),
	(12, 13, 'KTM RC 200', 2015, 'BLACK', 'VBKJYC405FC006231', '', '5-906*01428*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '2015-07-31', '', 'sold', 'Invoice 6', ''),
	(13, 13, 'KTM RC 200', 2015, 'BLACK', 'VBKJYC409FC006278', '', '5-906*01466*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'sold', 'Invoice 9', ''),
	(14, 13, 'KTM RC 200', 2015, 'BLACK', 'VBKJYC401FC006260', '', '5-906*01405*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'sold', 'Invoice 13', ''),
	(15, 13, 'KTM RC 200 ', 2015, 'BLACK', 'VBKJYC407FC006246', ' ', '5-906*01410*', '', '200', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'BRAND NEW', '', ''),
	(16, 14, 'KTM RC 390', 2015, 'WHITE', 'VBKJYJ403FC210983', '', '5-902*05964*', '', '390', '', '', '', '0000-00-00', '2015-07-31', '2015-07-31', '', 'BRAND NEW', '', ''),
	(17, 2, 'DUCATI HYPERMOTARD 821', 2014, 'RED', '*ML0B100AAET001107*', '', 'ZDM821W4C*001131*', '', '821', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'BRAND NEW', '', ''),
	(18, 26, 'VESPA PRIMAVERA 3V IE 150', 2015, 'BLACK', '*RP8M822EV004545*', '', '*M822M*5005578*', '', '150', '', '', '', '0000-00-00', '2015-07-31', '0000-00-00', '', 'BRAND NEW', '', ''),
	(19, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ400EC226785', 'LC-37089', '4-902*12857*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '2015-09-22', '', 'DEMO', '', ''),
	(20, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ409EC226767', '', '4-902*12876*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(21, 22, 'KTM DUKE 390', 2014, 'BLACK', 'VBKJGJ403EC226957', '', '4-902*12420*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(22, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ406EC226810', '', '4-902*12714*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(23, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ403EC226523', '', '4-902*12269*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(24, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ409EC226526', '', '4-902*12604*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(25, 22, 'KTM DUKE 390', 2014, 'BLACK', 'VBKJGJ406EC226967', '', '4-902*13043*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(26, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ403EC231768', '', '4-902*17193*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(27, 22, 'KTM DUKE 390', 2014, 'BLACK', 'VBKJGJ407EC226928', '', '4-902*12929*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(28, 22, 'KTM DUKE 390', 2014, 'WHITE', 'VBKJGJ40XEC226812', '', '4-902*12862*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(29, 22, 'KTM DUKE 390', 2014, 'BLACK', 'VBKJGJ40XEC227006', '', '4-902*13089*', '', '390', '', '', '', '0000-00-00', '2015-09-22', '0000-00-00', '', 'BRAND NEW', '', ''),
	(30, 23, 'FZ 09 ', 2014, 'ORANGE', 'JYARN33E1EA001902', '', 'N702E-002500', '', '900', '', '', '', '0000-00-00', '2015-07-31', '2015-07-31', '', 'sold', 'Invoice 5', ''),
	(31, 1414, 'Italjet', 2015, 'Red/White', 'ZJTFRB8E2BL500229', '', 'LJ1P52QMI*15013774*', '', '125', 'SHOW ROOM', '', '', '0000-00-00', '2015-10-20', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(32, 1414, 'Italjet', 2015, 'Red/White', 'ZJTFRB8E8BL500221', '', 'LJ1P52QMI*15013726*', '', '125', 'SHOW ROOM', '', '', '0000-00-00', '2015-10-20', '0000-00-00', '', 'sold', 'Invoice 27', '0'),
	(33, 1415, 'KAWASAKI VERSYS 1000', 2015, 'LIME GREEN', 'LZT 00B-006149', '', 'ZRT00DE089450', '', '1000', 'SHOW ROOM', '', '', '0000-00-00', '2015-10-20', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(34, 1416, 'KTM RC 200', 2015, 'BLACK', 'VBKJYC409FC006250', '', '5-906*01297*', '', '200', 'SHOW ROOM', '', '', '0000-00-00', '2015-10-20', '0000-00-00', '', 'sold', 'Invoice 29', '0'),
	(35, 1422, 'KTM', 2015, 'BLACK', 'VBKJYC404FC006284', '', '5-906*01546*', '', '200', 'SATELLITE PI', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(36, 1423, 'KTM', 2015, 'BLACK', 'VBKJYC405FC006276', '', '5-906*01427*', '', '200', 'SATELLITE PI', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(37, 1424, 'KTM', 2014, 'ORANGE', 'VBKJUC403EC023555', '', '4-906*54931*', '', '200', 'SATELLITE PI', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(38, 1425, 'KTM ', 2014, 'ORANGE', 'VBKJUC406EC023548', '', '4-906*54837', '', '200', 'SHOW ROOM', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(39, 1426, 'KTM', 2014, 'WHITE', 'VKJUC406EC027907', '', '4-906*54837*', '', '200', 'SHOW ROOM', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(40, 1427, 'KTM ', 2015, 'BLACK', 'VBKJYC40XFC006273', '', '5-906*01457*', '', '200', 'SHOW ROOM', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(41, 1428, 'KTM', 2015, 'WHITE', 'VBKJYJ408FC210994', '', '5-902*06156*', '', '390', 'SHOW ROOM', '', '', '0000-00-00', '2015-11-19', '0000-00-00', '', 'BRAND NEW', '', '0'),
	(42, 1471, 'Scrambler Icon  ', 2015, 'Yellow ', 'ML0K100AAFT000958', '', 'ML0800A2D000432', '', '805', 'DEMO', '', '', '0000-00-00', '2015-11-25', '0000-00-00', '', 'DEMO', '', '0');
/*!40000 ALTER TABLE `tblmotorbikes` ENABLE KEYS */;


-- Dumping structure for table invndc.tblorder
DROP TABLE IF EXISTS `tblorder`;
CREATE TABLE IF NOT EXISTS `tblorder` (
  `idOrder` int(15) NOT NULL DEFAULT '0',
  `idSupplier` int(10) DEFAULT NULL,
  `dateOrdered` date DEFAULT NULL,
  `deliveryDate` date DEFAULT NULL,
  `requestBy` int(10) DEFAULT NULL,
  `transtype` varchar(15) DEFAULT NULL,
  `orderStatus` varchar(15) DEFAULT NULL,
  `paymentMode` varchar(50) DEFAULT NULL,
  `paymentType` varchar(50) DEFAULT NULL,
  `dateReceived` date DEFAULT NULL,
  `receivedBy` varchar(70) DEFAULT NULL,
  `receivingRemarks` text,
  `poID` varchar(16) NOT NULL,
  `roID` varchar(16) NOT NULL,
  `checkedBy` varchar(70) DEFAULT NULL,
  `courier` varchar(50) DEFAULT NULL,
  `poChecker` varchar(30) DEFAULT NULL,
  `poApproval` varchar(30) DEFAULT NULL,
  `shipTo` int(3) DEFAULT NULL,
  `shipVia` int(3) DEFAULT NULL,
  `idMode` int(1) DEFAULT NULL,
  `idTerm` int(3) DEFAULT NULL,
  `checkNo` varchar(20) DEFAULT NULL,
  `rcptNo` varchar(20) DEFAULT NULL,
  PRIMARY KEY (`idOrder`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblorder: ~34 rows (approximately)
/*!40000 ALTER TABLE `tblorder` DISABLE KEYS */;
INSERT INTO `tblorder` (`idOrder`, `idSupplier`, `dateOrdered`, `deliveryDate`, `requestBy`, `transtype`, `orderStatus`, `paymentMode`, `paymentType`, `dateReceived`, `receivedBy`, `receivingRemarks`, `poID`, `roID`, `checkedBy`, `courier`, `poChecker`, `poApproval`, `shipTo`, `shipVia`, `idMode`, `idTerm`, `checkNo`, `rcptNo`) VALUES
	(2015, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '', '', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(2016, 0, NULL, '2015-08-01', NULL, NULL, 'received', NULL, NULL, '2015-08-03', 'Joseph V. Del Rosario Jr.', '', '0', '2015-1', 'Girlie G. Tolosa', 'IOP', NULL, NULL, NULL, NULL, 0, 0, '0', '674'),
	(2017, 0, NULL, '2015-08-07', NULL, NULL, 'received', NULL, NULL, '2015-08-11', 'Joseph V. Del Rosario Jr.', '', '0', '2015-2', 'Girlie G. Tolosa', 'Air21', NULL, NULL, NULL, NULL, 0, 0, '0', '93'),
	(2018, 0, NULL, '2015-08-11', NULL, NULL, 'received', NULL, NULL, '2015-08-26', 'Joseph V. Del Rosario Jr.', '', '0', '2015-3', 'Girlie G. Tolosa', 'IOP', NULL, NULL, NULL, NULL, 0, 0, '0', '679'),
	(2019, 0, NULL, '2015-07-27', NULL, NULL, 'received', NULL, NULL, '2015-08-26', 'Joseph V. Del Rosario Jr.', '', '0', '2015-4', 'Girlie G. Tolosa', 'IOP', NULL, NULL, NULL, NULL, 0, 0, '0', '671'),
	(2020, 0, NULL, '2015-08-25', NULL, NULL, 'received', NULL, NULL, '2015-08-26', 'Joseph V. Del Rosario Jr.', '', '0', '2015-5', 'Girlie G. Tolosa', 'IOP', NULL, NULL, NULL, NULL, 0, 0, '0', '99'),
	(2021, 0, NULL, '2015-09-07', NULL, NULL, 'received', NULL, NULL, '2015-09-10', 'Girlie G. Tolosa', '', '0', '2015-6', 'Darylle B. Battad', 'c/o LGB', NULL, NULL, NULL, NULL, 0, 0, '0', '703'),
	(2022, 0, NULL, '2015-08-29', NULL, NULL, 'received', NULL, NULL, '2015-09-03', 'Girlie G. Tolosa', '', '0', '2015-7', 'Darylle B. Battad', 'Air21', NULL, NULL, NULL, NULL, 0, 0, '0', '692'),
	(2023, 0, NULL, '2015-08-29', NULL, NULL, 'received', NULL, NULL, '2015-09-03', 'Girlie G. Tolosa', '', '0', '2015-7', 'Darylle B. Battad', 'Air21', NULL, NULL, NULL, NULL, 0, 0, '0', '692'),
	(2024, 0, NULL, '2015-08-29', NULL, NULL, 'received', NULL, NULL, '2015-09-03', 'Girlie G. Tolosa', '', '0', '2015-8', 'Darylle B. Battad', 'Air21', NULL, NULL, NULL, NULL, 0, 0, '0', '693'),
	(2025, 0, NULL, '2015-08-29', NULL, NULL, 'received', NULL, NULL, '2015-09-03', 'Girlie G. Tolosa', '', '0', '2015-8', 'Darylle B. Battad', 'Air21', NULL, NULL, NULL, NULL, 0, 0, '0', '693'),
	(2026, 0, NULL, '2015-09-10', NULL, NULL, 'received', NULL, NULL, '2015-09-10', 'Girlie G. Tolosa', '', '0', '2015-9', 'Darylle B. Battad', 'JRL', NULL, NULL, NULL, NULL, 0, 0, '0', '709'),
	(2027, 0, NULL, '2015-09-10', NULL, NULL, 'received', NULL, NULL, '2015-09-10', 'Girlie G. Tolosa', '', '0', '2015-9', 'Darylle B. Battad', 'JRL', NULL, NULL, NULL, NULL, 0, 0, '0', '709'),
	(2028, 0, NULL, '2015-10-01', NULL, NULL, 'received', NULL, NULL, '2015-10-01', 'Joseph V. Del Rosario Jr.', '', '0', '2015-10', 'Norben Jay L.  Ruiz', 'IOP', NULL, NULL, NULL, NULL, 0, 0, '0', '01'),
	(2029, 0, NULL, '2015-08-25', NULL, NULL, 'received', NULL, NULL, '2015-08-26', 'Joseph V. Del Rosario Jr.', '', '0', '2015-11', 'Norben Jay L.  Ruiz', 'IOP', NULL, NULL, NULL, NULL, 0, 0, '0', '99'),
	(2030, 0, NULL, '2015-09-29', NULL, NULL, 'received', NULL, NULL, '2015-10-03', 'Joseph V. Del Rosario Jr.', '', '0', '2015-12', 'Norben Jay L.  Ruiz', 'None', NULL, NULL, NULL, NULL, 0, 0, '0', '716'),
	(2031, 0, NULL, '2015-10-05', NULL, NULL, 'received', NULL, NULL, '2015-10-05', 'Joseph V. Del Rosario Jr.', '', '0', '2015-13', 'Leo Alfie A. Quipanes', 'None', NULL, NULL, NULL, NULL, 8, 0, '0', '112312'),
	(2032, 0, NULL, '0000-00-00', NULL, NULL, 'received', NULL, NULL, '2015-10-05', 'Joseph V. Del Rosario Jr.', '', '0', '2015-14', 'Leo Alfie A. Quipanes', 'None', NULL, NULL, NULL, NULL, 8, 0, '0', '0854'),
	(2033, 0, NULL, '2015-10-09', NULL, NULL, 'received', NULL, NULL, '2015-10-09', 'Joseph V. Del Rosario Jr.', '', '0', '2015-15', 'Leo Alfie A. Quipanes', 'Air21', NULL, NULL, NULL, NULL, 0, 0, '0', '002'),
	(2034, 14, NULL, '2015-10-14', NULL, NULL, 'received', NULL, NULL, '2015-10-16', 'Girlie G. Tolosa', '', '0', '2015-16', 'Girlie G. Tolosa', 'NDC CDO C/O PAUL', NULL, NULL, NULL, NULL, 0, 0, '0', '2015-9'),
	(2035, 5, NULL, '2015-10-14', NULL, NULL, 'received', NULL, NULL, '2015-10-16', 'Girlie G. Tolosa', '', '0', '2015-17', 'Girlie G. Tolosa', 'NDC CDO C/O PAUL', NULL, NULL, NULL, NULL, 0, 0, '0', '2015-9'),
	(2036, 7, NULL, '2015-10-13', NULL, NULL, 'received', NULL, NULL, '2015-10-16', 'Girlie G. Tolosa', '', '0', '2015-18', 'Girlie G. Tolosa', 'NDC DVO thru NLR', NULL, NULL, NULL, NULL, 0, 0, '0', '732'),
	(2037, 7, NULL, '2015-10-14', NULL, NULL, 'received', NULL, NULL, '2015-10-16', 'Girlie G. Tolosa', '', '0', '2015-19', 'Girlie G. Tolosa', 'CDO c/o Paul', NULL, NULL, NULL, NULL, 0, 0, '0', '112'),
	(2038, 0, NULL, '2015-10-14', NULL, NULL, 'received', NULL, NULL, '2015-10-16', 'Girlie G. Tolosa', '', '0', '2015-20', 'Girlie G. Tolosa', 'ndc cdo c/o paul', NULL, NULL, NULL, NULL, 0, 0, '0', '2015-11'),
	(2039, 7, NULL, '2015-11-07', NULL, NULL, 'received', NULL, NULL, '2015-11-11', 'Girlie G. Tolosa', '', '0', '2015-21', 'Girlie G. Tolosa', 'DVO thru: LBC', NULL, NULL, NULL, NULL, 0, 0, '0', '751'),
	(2040, 7, NULL, '2015-11-16', NULL, NULL, 'received', NULL, NULL, '2015-11-18', 'Girlie G. Tolosa', '', '0', '2015-22', 'Girlie G. Tolosa', 'CDO thru A. Boniel', NULL, NULL, NULL, NULL, 0, 0, '0', '4'),
	(2041, 0, NULL, '2015-09-10', NULL, NULL, 'received', NULL, NULL, '2015-09-10', 'Girlie G. Tolosa', 'from DVO with ride event last 09/10/15 but NO DR', '0', '2015-23', 'Girlie G. Tolosa', 'thru Lanzi ', NULL, NULL, NULL, NULL, 0, 0, '0', 'none'),
	(2042, 0, NULL, '2015-11-14', NULL, NULL, 'received', NULL, NULL, '2015-11-17', 'Girlie G. Tolosa', '', '0', '2015-24', 'Girlie G. Tolosa', 'CDO thru: A. Boniel', NULL, NULL, NULL, NULL, 0, 0, '0', '5'),
	(2043, 1, NULL, '2015-11-21', NULL, NULL, 'received', NULL, NULL, '2015-11-23', 'Girlie G. Tolosa', '', '0', '2015-25', 'Girlie G. Tolosa', 'DVO thru Iris Trinidad', NULL, NULL, NULL, NULL, 0, 0, '0', '758'),
	(2044, 21, NULL, '2015-11-21', NULL, NULL, 'received', NULL, NULL, '2015-11-23', 'Girlie G. Tolosa', '', '0', '2015-26', 'Girlie G. Tolosa', 'DVO thru Iris Trinidad', NULL, NULL, NULL, NULL, 0, 0, '0', '758'),
	(2045, 6, NULL, '2015-11-21', NULL, NULL, 'received', NULL, NULL, '2015-11-23', 'Girlie G. Tolosa', '', '0', '2015-27', 'Girlie G. Tolosa', 'DVO thru Iris Trinidad', NULL, NULL, NULL, NULL, 0, 0, '0', '760'),
	(2046, 6, NULL, '2015-11-21', NULL, NULL, 'received', NULL, NULL, '2015-11-23', 'Girlie G. Tolosa', '', '0', '2015-28', 'Girlie G. Tolosa', 'DVO thru Iris Trinidad', NULL, NULL, NULL, NULL, 0, 0, '0', '759'),
	(2047, 6, NULL, '2015-12-08', NULL, NULL, 'received', NULL, NULL, '2015-12-10', 'Girlie G. Tolosa', '', '0', '2015-29', 'Girlie G. Tolosa', 'Ndc cdo thru Sir Marlon', NULL, NULL, NULL, NULL, 0, 0, '0', '1'),
	(2048, 0, NULL, '2015-12-11', NULL, NULL, 'received', NULL, NULL, '2015-12-08', 'Girlie G. Tolosa', '', '0', '2015-30', 'Girlie G. Tolosa', 'dvo thru air21', NULL, NULL, NULL, NULL, 0, 0, '0', '769');
/*!40000 ALTER TABLE `tblorder` ENABLE KEYS */;


-- Dumping structure for table invndc.tblordereditems
DROP TABLE IF EXISTS `tblordereditems`;
CREATE TABLE IF NOT EXISTS `tblordereditems` (
  `pk` int(15) NOT NULL AUTO_INCREMENT,
  `idOrder` int(10) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `quantity` int(3) NOT NULL,
  `idUnit` int(2) DEFAULT NULL,
  `cost` double(12,2) unsigned zerofill DEFAULT NULL,
  `balance` int(5) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `qtypending` int(5) NOT NULL,
  `qtyreceived` int(5) NOT NULL,
  `qtyreturned` int(5) NOT NULL,
  `returnRemarks` varchar(100) NOT NULL,
  `dateReceived` date DEFAULT NULL,
  `srp` double(18,2) DEFAULT NULL,
  `dealerPrice` double(18,2) DEFAULT NULL,
  `remarks` varchar(30) DEFAULT NULL,
  `roID` varchar(15) DEFAULT NULL,
  `taxStatus` varchar(25) DEFAULT NULL,
  `idSupplier` int(10) DEFAULT NULL,
  PRIMARY KEY (`pk`)
) ENGINE=InnoDB AUTO_INCREMENT=131 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblordereditems: ~119 rows (approximately)
/*!40000 ALTER TABLE `tblordereditems` DISABLE KEYS */;
INSERT INTO `tblordereditems` (`pk`, `idOrder`, `idItem`, `quantity`, `idUnit`, `cost`, `balance`, `status`, `qtypending`, `qtyreceived`, `qtyreturned`, `returnRemarks`, `dateReceived`, `srp`, `dealerPrice`, `remarks`, `roID`, `taxStatus`, `idSupplier`) VALUES
	(1, 2016, 289, 0, 1, 000000000.00, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(2, 2017, 617, 0, 1, 000001414.29, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(3, 2018, 288, 0, 1, 000002035.00, 0, 'received', 0, 3, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(4, 2018, 287, 0, 9, 000007300.00, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(5, 2018, 286, 0, 1, 000001669.50, 0, 'received', 0, 2, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(6, 2018, 317, 0, 1, 000000295.00, 0, 'received', 0, 5, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(7, 2018, 319, 0, 1, 000000385.00, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(8, 2018, 318, 0, 1, 000000385.00, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(9, 2018, 285, 0, 1, 000002750.00, 0, 'received', 0, 4, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(10, 2019, 312, 0, 9, 000001085.00, 0, 'received', 0, 2, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(11, 2019, 313, 0, 9, 000001085.00, 0, 'received', 0, 5, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(12, 2019, 311, 0, 9, 000001085.00, 0, 'received', 0, 5, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(13, 2019, 310, 0, 9, 000000644.00, 0, 'received', 0, 5, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(14, 2019, 443, 0, 1, 000000647.00, 0, 'received', 0, 5, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(15, 2020, 306, 0, 1, 000002415.00, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(16, 2020, 790, 0, 1, 000000128.53, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(17, 2020, 791, 0, 1, 000000128.53, 0, 'received', 0, 1, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(18, 2020, 807, 0, 1, 000000145.85, 0, 'received', 0, 0, 0, '', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
	(19, 2021, 1377, 0, 4, 000000432.00, 0, 'received', 0, 5, 0, '0.00', '2015-09-10', 670.00, 0.00, 'received', '2015-6', '', 0),
	(20, 2023, 1380, 0, 1, 000001125.00, 0, 'received', 0, 1, 0, '0.00', '2015-09-03', 2310.00, 0.00, 'received', '2015-7', '', 0),
	(21, 2025, 1381, 0, 1, 000000080.00, 0, 'received', 0, 5, 0, '0.00', '2015-09-03', 150.00, 0.00, 'received', '2015-8', '', 0),
	(22, 2027, 1382, 0, 9, 000036523.00, 0, 'received', 0, 1, 0, '0.00', '2015-09-10', 52175.00, 0.00, 'received', '2015-9', '', 0),
	(23, 2028, 1383, 0, 1, 000000181.58, 0, 'received', 0, 6, 0, '0.00', '2015-10-01', 290.00, 290.00, 'received', '2015-10', '', 0),
	(24, 2029, 1384, 0, 1, 000000128.00, 0, 'received', 0, 1, 0, '0.00', '2015-08-26', 550.00, 550.00, 'received', '2015-11', '', 0),
	(25, 2029, 1386, 0, 1, 000000128.00, 0, 'received', 0, 1, 0, '0.00', '2015-08-26', 550.00, 550.00, 'received', '2015-11', '', 0),
	(26, 2030, 1387, 0, 1, 000000653.25, 0, 'received', 0, 1, 0, '0.00', '2015-10-03', 900.00, 900.00, 'received', '2015-12', 'VAT', 0),
	(27, 2030, 583, 0, 1, 000003899.99, 0, 'received', 0, 3, 0, '0.00', '2015-10-03', 6010.00, 6010.00, 'received', '2015-12', 'VAT', 0),
	(28, 2030, 530, 0, 1, 000000535.72, 0, 'received', 0, 2, 0, '0.00', '2015-10-03', 1100.00, 1100.00, 'received', '2015-12', 'VAT', 0),
	(29, 2030, 441, 0, 1, 000000535.71, 0, 'received', 0, 1, 0, '0.00', '2015-10-03', 825.00, 825.00, 'received', '2015-12', 'VAT', 0),
	(30, 2030, 415, 0, 1, 000000807.14, 0, 'received', 0, 1, 0, '0.00', '2015-10-03', 1430.00, 1430.00, 'received', '2015-12', 'VAT', 0),
	(31, 2030, 1388, 0, 1, 000000053.57, 0, 'received', 0, 1, 0, '0.00', '2015-10-03', 125.00, 125.00, 'received', '2015-12', 'VAT', 6),
	(32, 2030, 1389, 0, 1, 000000187.71, 0, 'received', 0, 1, 0, '0.00', '2015-10-03', 550.00, 550.00, 'received', '2015-12', 'VAT', 6),
	(33, 2030, 1364, 0, 4, 000000466.07, 0, 'received', 0, 5, 0, '0.00', '2015-10-03', 805.00, 466.07, 'received', '2015-12', 'VAT', 0),
	(34, 2030, 1372, 0, 4, 000000432.00, 0, 'received', 0, 2, 0, '0.00', '2015-10-03', 670.00, 432.00, 'received', '2015-12', 'VAT', 0),
	(35, 2031, 1390, 0, 1, 000000175.00, 0, 'received', 0, 1, 0, '0.00', '2015-10-05', 175.00, 175.00, 'received', '2015-13', 'VAT', 0),
	(36, 2031, 1391, 0, 5, 000000145.00, 0, 'received', 0, 1, 0, '0.00', '2015-10-05', 145.00, 145.00, 'received', '2015-13', 'VAT', 0),
	(37, 2032, 1392, 0, 1, 000000160.00, 0, 'received', 0, 1, 0, '0.00', '2015-10-05', 160.00, 160.00, 'received', '2015-14', 'VAT', 0),
	(38, 2032, 1393, 0, 1, 000000030.00, 0, 'received', 0, 1, 0, '0.00', '2015-10-05', 30.00, 30.00, 'received', '2015-14', 'VAT', 0),
	(39, 2032, 1394, 0, 1, 000000027.00, 0, 'received', 0, 1, 0, '0.00', '2015-10-05', 27.00, 27.00, 'received', '2015-14', 'VAT', 0),
	(40, 2033, 1397, 0, 1, 000000000.00, 0, 'received', 0, 1, 0, '0.00', '2015-10-09', 250.00, 250.00, 'received', '2015-15', 'VAT', 0),
	(41, 2034, 1399, 0, 2, 000000625.00, 0, 'received', 0, 1, 0, '', '2015-10-16', 1080.00, 0.00, 'received', '2015-16', 'VAT', 14),
	(42, 2034, 1400, 0, 10, 000000800.00, 0, 'received', 0, 2, 0, '', '2015-10-16', 1390.00, 0.00, 'received', '2015-16', 'VAT', 14),
	(43, 2035, 1401, 0, 1, 000002500.00, 0, 'received', 0, 2, 0, '', '2015-10-16', 5555.00, 0.00, 'received', '2015-17', 'VAT', 5),
	(44, 2035, 1402, 0, 1, 000002500.00, 0, 'received', 0, 1, 0, '', '2015-10-16', 5555.00, 0.00, 'received', '2015-17', 'VAT', 5),
	(45, 2035, 1403, 0, 1, 000002500.00, 0, 'received', 0, 1, 0, '', '2015-10-16', 5555.00, 0.00, 'received', '2015-17', 'VAT', 5),
	(46, 2035, 1404, 0, 1, 000002500.00, 0, 'received', 0, 1, 0, '', '2015-10-16', 5555.00, 0.00, 'received', '2015-17', 'VAT', 5),
	(47, 2035, 1405, 0, 1, 000002500.00, 0, 'received', 0, 1, 0, '', '2015-10-16', 5555.00, 0.00, 'received', '2015-17', 'VAT', 5),
	(48, 2036, 1406, 0, 1, 000000388.57, 0, 'received', 0, 1, 0, '', '2015-10-16', 600.00, 0.00, 'received', '2015-18', 'VAT', 7),
	(49, 2037, 1414, 0, 3, 000115000.00, 0, 'received', 0, 2, 0, '', '2015-10-16', 115000.00, 0.00, 'received', '2015-19', 'VAT', 7),
	(53, 2038, 1417, 0, 3, 000057379.68, 0, 'received', 0, 1, 0, '', '2015-10-16', 75000.00, 0.00, 'received', '2015-20', 'VAT', 0),
	(54, 2039, 1418, 0, 1, 000001339.28, 0, 'received', 0, 1, 0, '', '2015-11-11', 2750.00, 0.00, 'received', '2015-21', 'VAT', 6),
	(55, 2039, 1419, 0, 3, 000001000.00, 0, 'received', 0, 1, 0, '', '2015-11-11', 1870.00, 0.00, 'received', '2015-21', 'VAT', 6),
	(56, 2039, 1420, 0, 1, 000000053.57, 0, 'received', 0, 1, 0, '', '2015-11-11', 110.00, 0.00, 'received', '2015-21', 'VAT', 6),
	(57, 2039, 1421, 0, 1, 000000262.50, 0, 'received', 0, 1, 0, '', '2015-11-11', 620.00, 0.00, 'received', '2015-21', 'VAT', 7),
	(58, 2040, 1422, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 199000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(59, 2040, 1423, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 199000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(60, 2040, 1424, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 169000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(61, 2040, 1425, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 169000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(62, 2040, 1426, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 169000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(63, 2040, 1427, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 199000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(64, 2040, 1428, 0, 3, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-11-18', 399000.00, 0.00, 'received', '2015-22', 'VAT', 7),
	(65, 2041, 1430, 0, 3, 000057379.68, 0, 'received', 0, 1, 0, '', '2015-09-10', 75000.00, 0.00, 'received', '2015-23', 'VAT', 0),
	(66, 2042, 1431, 0, 15, 000000466.07, 0, 'received', 0, 5, 0, '', '2015-11-17', 805.00, 0.00, 'received', '2015-24', 'VAT', 3),
	(67, 2042, 1432, 0, 15, 000000432.00, 0, 'received', 0, 5, 0, '', '2015-11-17', 670.00, 0.00, 'received', '2015-24', 'VAT', 3),
	(68, 2042, 1433, 0, 1, 000001382.50, 0, 'received', 0, 1, 0, '', '2015-11-17', 2420.00, 0.00, 'received', '2015-24', 'VAT', 14),
	(69, 2042, 1434, 0, 1, 000000128.53, 0, 'received', 0, 2, 0, '', '2015-11-17', 550.00, 0.00, 'received', '2015-24', 'VAT', 0),
	(70, 2043, 1435, 0, 1, 000003931.25, 0, 'received', 0, 1, 0, '', '2015-11-23', 6920.00, 0.00, 'received', '2015-25', 'VAT', 1),
	(71, 2043, 1436, 0, 1, 000003931.25, 0, 'received', 0, 1, 0, '', '2015-11-23', 6920.00, 0.00, 'received', '2015-25', 'VAT', 1),
	(72, 2043, 1437, 0, 1, 000002868.75, 0, 'received', 0, 1, 0, '', '2015-11-23', 6590.00, 0.00, 'received', '2015-25', 'VAT', 1),
	(73, 2043, 1438, 0, 1, 000003056.25, 0, 'received', 0, 1, 0, '', '2015-11-23', 5380.00, 0.00, 'received', '2015-25', 'VAT', 1),
	(74, 2043, 1439, 0, 1, 000002868.75, 0, 'received', 0, 1, 0, '', '2015-11-23', 5555.00, 0.00, 'received', '2015-25', 'VAT', 1),
	(75, 2043, 1440, 0, 1, 000002742.19, 0, 'received', 0, 1, 0, '', '2015-11-23', 4730.00, 0.00, 'received', '2015-25', 'VAT', 16),
	(76, 2043, 1441, 0, 1, 000002742.19, 0, 'received', 0, 1, 0, '', '2015-11-23', 4730.00, 0.00, 'received', '2015-25', 'VAT', 16),
	(77, 2043, 1442, 0, 1, 000002340.40, 0, 'received', 0, 1, 0, '', '2015-11-23', 4040.00, 0.00, 'received', '2015-25', 'VAT', 16),
	(78, 2043, 1443, 0, 1, 000002742.18, 0, 'received', 0, 1, 0, '', '2015-11-23', 4505.00, 0.00, 'received', '2015-25', 'VAT', 16),
	(79, 2043, 1444, 0, 1, 000002142.86, 0, 'received', 0, 1, 0, '', '2015-11-23', 4150.00, 0.00, 'received', '2015-25', 'VAT', 2),
	(80, 2043, 1445, 0, 1, 000001900.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 3675.00, 0.00, 'received', '2015-25', 'VAT', 2),
	(81, 2043, 1446, 0, 4, 000000353.57, 0, 'received', 0, 12, 0, '', '2015-11-23', 655.00, 0.00, 'received', '2015-25', 'VAT', 3),
	(82, 2043, 1447, 0, 4, 000000371.43, 0, 'received', 0, 6, 0, '', '2015-11-23', 670.00, 0.00, 'received', '2015-25', 'VAT', 3),
	(83, 2043, 1448, 0, 1, 000005785.71, 0, 'received', 0, 1, 0, '', '2015-11-23', 9988.00, 0.00, 'received', '2015-25', 'VAT', 3),
	(84, 2043, 1449, 0, 1, 000000763.39, 0, 'received', 0, 2, 0, '', '2015-11-23', 1320.00, 0.00, 'received', '2015-25', 'VAT', 4),
	(85, 2043, 1450, 0, 1, 000000830.35, 0, 'received', 0, 2, 0, '', '2015-11-23', 2090.00, 0.00, 'received', '2015-25', 'VAT', 6),
	(86, 2043, 1451, 0, 1, 000001125.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 2310.00, 0.00, 'received', '2015-25', 'VAT', 6),
	(87, 2044, 1452, 0, 9, 000002800.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 6240.00, 0.00, 'received', '2015-26', 'NON-VAT', 21),
	(88, 2045, 1453, 0, 1, 000006087.63, 0, 'received', 0, 1, 0, '', '2015-11-23', 11330.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(89, 2045, 1454, 0, 1, 000006087.63, 0, 'received', 0, 1, 0, '', '2015-11-23', 11330.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(90, 2045, 1455, 0, 1, 000001805.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 3410.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(91, 2045, 1456, 0, 1, 000001805.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 3410.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(92, 2045, 1457, 0, 1, 000001805.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 3410.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(93, 2045, 1458, 0, 1, 000001805.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 3410.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(94, 2045, 1459, 0, 1, 000001805.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 3410.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(95, 2045, 1460, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(96, 2045, 1461, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(97, 2045, 1462, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(98, 2045, 1463, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(99, 2045, 1464, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(100, 2045, 1465, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(101, 2045, 1466, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(102, 2045, 1467, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(103, 2045, 1468, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(104, 2045, 1469, 0, 1, 000000917.77, 0, 'received', 0, 2, 0, '', '2015-11-23', 1760.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(105, 2045, 1470, 0, 1, 000001499.64, 0, 'received', 0, 1, 0, '', '2015-11-23', 2860.00, 0.00, 'received', '2015-27', 'VAT', 6),
	(106, 2046, 1471, 0, 3, 000540000.00, 0, 'received', 0, 1, 0, '', '2015-11-23', 540000.00, 0.00, 'received', '2015-28', 'VAT', 6),
	(107, 2047, 1472, 0, 1, 000000501.29, 0, 'received', 0, 2, 0, '', '2015-12-10', 925.00, 0.00, 'received', '2015-29', '', 3),
	(108, 2047, 1473, 0, 1, 000003529.46, 0, 'received', 0, 1, 0, '', '2015-12-10', 5705.00, 0.00, 'received', '2015-29', '', 6),
	(109, 2047, 1474, 0, 1, 000003239.29, 0, 'received', 0, 1, 0, '', '2015-12-10', 5705.00, 0.00, 'received', '2015-29', '', 6),
	(110, 2047, 1475, 0, 1, 000003239.29, 0, 'received', 0, 1, 0, '', '2015-12-10', 5705.00, 0.00, 'received', '2015-29', '', 6),
	(111, 2047, 1476, 0, 1, 000000466.96, 0, 'received', 0, 4, 0, '', '2015-12-10', 965.00, 0.00, 'received', '2015-29', '', 6),
	(112, 2047, 1477, 0, 1, 000000803.57, 0, 'received', 0, 3, 0, '', '2015-12-10', 1390.00, 0.00, 'received', '2015-29', '', 4),
	(113, 2047, 1478, 0, 1, 000008750.00, 0, 'received', 0, 1, 0, '', '2015-12-10', 10780.00, 0.00, 'received', '2015-29', '', 7),
	(114, 2047, 1479, 0, 1, 000001721.25, 0, 'received', 0, 1, 0, '', '2015-12-10', 2655.00, 0.00, 'received', '2015-29', '', 16),
	(115, 2047, 1480, 0, 1, 000000000.00, 0, 'received', 0, 1, 0, '', '2015-12-10', 2310.00, 0.00, 'received', '2015-29', '', 16),
	(116, 2048, 1481, 0, 1, 000004462.50, 0, 'received', 0, 1, 0, '', '2015-12-08', 7000.00, 0.00, 'received', '2015-30', 'VAT', 14),
	(117, 2048, 1482, 0, 9, 000008500.00, 0, 'received', 0, 1, 0, '', '2015-12-08', 14720.00, 0.00, 'received', '2015-30', 'VAT', 14),
	(118, 2048, 1483, 0, 9, 000001192.63, 0, 'received', 0, 1, 0, '', '2015-12-08', 1840.00, 0.00, 'received', '2015-30', 'VAT', 7),
	(119, 2048, 1484, 0, 9, 000004660.72, 0, 'received', 0, 1, 0, '', '2015-12-08', 8045.00, 0.00, 'received', '2015-30', 'VAT', 6),
	(120, 2048, 1485, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(121, 2048, 1486, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(122, 2048, 1487, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(123, 2048, 1488, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(124, 2048, 1489, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(125, 2048, 1490, 0, 1, 000000144.96, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(126, 2048, 1491, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(127, 2048, 1492, 0, 1, 000000144.96, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(128, 2048, 1493, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(129, 2048, 1494, 0, 1, 000000130.22, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0),
	(130, 2048, 1495, 0, 1, 000000144.96, 0, 'received', 0, 1, 0, '', '2015-12-08', 550.00, 0.00, 'received', '2015-30', 'VAT', 0);
/*!40000 ALTER TABLE `tblordereditems` ENABLE KEYS */;


-- Dumping structure for table invndc.tblorderreturn
DROP TABLE IF EXISTS `tblorderreturn`;
CREATE TABLE IF NOT EXISTS `tblorderreturn` (
  `idReturn` int(15) NOT NULL AUTO_INCREMENT,
  `idOrder` int(15) DEFAULT NULL,
  `dateReturn` date DEFAULT NULL,
  `processedReturn` int(10) DEFAULT NULL,
  PRIMARY KEY (`idReturn`)
) ENGINE=MyISAM AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblorderreturn: 0 rows
/*!40000 ALTER TABLE `tblorderreturn` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblorderreturn` ENABLE KEYS */;


-- Dumping structure for table invndc.tblorderreturnitems
DROP TABLE IF EXISTS `tblorderreturnitems`;
CREATE TABLE IF NOT EXISTS `tblorderreturnitems` (
  `id` int(15) NOT NULL DEFAULT '0',
  `idReturn` int(15) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `quantity` int(3) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblorderreturnitems: 1 rows
/*!40000 ALTER TABLE `tblorderreturnitems` DISABLE KEYS */;
INSERT INTO `tblorderreturnitems` (`id`, `idReturn`, `idItem`, `quantity`) VALUES
	(0, NULL, NULL, NULL);
/*!40000 ALTER TABLE `tblorderreturnitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tblownertypes
DROP TABLE IF EXISTS `tblownertypes`;
CREATE TABLE IF NOT EXISTS `tblownertypes` (
  `idOwner` int(2) DEFAULT NULL,
  `Owner` varchar(25) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblownertypes: 3 rows
/*!40000 ALTER TABLE `tblownertypes` DISABLE KEYS */;
INSERT INTO `tblownertypes` (`idOwner`, `Owner`) VALUES
	(1, 'Compnay Manager'),
	(2, 'Company Employee'),
	(3, 'New Owner');
/*!40000 ALTER TABLE `tblownertypes` ENABLE KEYS */;


-- Dumping structure for table invndc.tblpaymentmode
DROP TABLE IF EXISTS `tblpaymentmode`;
CREATE TABLE IF NOT EXISTS `tblpaymentmode` (
  `idMode` int(1) DEFAULT NULL,
  `modeName` varchar(50) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblpaymentmode: 7 rows
/*!40000 ALTER TABLE `tblpaymentmode` DISABLE KEYS */;
INSERT INTO `tblpaymentmode` (`idMode`, `modeName`) VALUES
	(1, 'Cash '),
	(5, 'Check (PDC)'),
	(7, 'Others'),
	(2, 'Credit Card'),
	(3, 'Debit Card'),
	(4, 'Check (OnDate)'),
	(6, 'Others');
/*!40000 ALTER TABLE `tblpaymentmode` ENABLE KEYS */;


-- Dumping structure for table invndc.tblpaymentterm
DROP TABLE IF EXISTS `tblpaymentterm`;
CREATE TABLE IF NOT EXISTS `tblpaymentterm` (
  `idTerm` int(3) NOT NULL DEFAULT '0',
  `termName` varchar(50) DEFAULT NULL,
  `idMode` int(1) DEFAULT NULL,
  PRIMARY KEY (`idTerm`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblpaymentterm: ~4 rows (approximately)
/*!40000 ALTER TABLE `tblpaymentterm` DISABLE KEYS */;
INSERT INTO `tblpaymentterm` (`idTerm`, `termName`, `idMode`) VALUES
	(1, '15 days', 2),
	(2, '30 days', 2),
	(3, '45 days', 2),
	(4, '60 days', 2);
/*!40000 ALTER TABLE `tblpaymentterm` ENABLE KEYS */;


-- Dumping structure for table invndc.tblpaymenttype
DROP TABLE IF EXISTS `tblpaymenttype`;
CREATE TABLE IF NOT EXISTS `tblpaymenttype` (
  `idType` int(2) NOT NULL DEFAULT '0',
  `typeName` varchar(25) DEFAULT NULL,
  `idMode` int(5) DEFAULT NULL,
  PRIMARY KEY (`idType`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblpaymenttype: 53 rows
/*!40000 ALTER TABLE `tblpaymenttype` DISABLE KEYS */;
INSERT INTO `tblpaymenttype` (`idType`, `typeName`, `idMode`) VALUES
	(1, 'Service', 1),
	(2, 'Motorbikes', 1),
	(3, 'Merchandise/MRP', 1),
	(4, 'Downpayment', 1),
	(5, 'Reservation', 1),
	(6, 'Shipping & Handling', 1),
	(7, 'Towing Fee', 1),
	(8, 'Financing', 1),
	(9, 'Registration', 1),
	(10, 'On Delivery', 1),
	(11, 'Service', 2),
	(12, 'Motorbikes', 2),
	(13, 'Merchandise/MRP', 2),
	(14, 'Downpayment', 2),
	(15, 'Reservation', 2),
	(16, 'Shipping & Handling', 2),
	(17, 'Towing Fee', 2),
	(18, 'Financing', 2),
	(19, 'Registration', 2),
	(20, 'Service', 3),
	(21, 'Motorbikes', 3),
	(22, 'Merchandise/MRP', 3),
	(23, 'Downpayment', 3),
	(24, 'Reservation', 3),
	(25, 'Shipping & Handling', 3),
	(26, 'Towing Fee', 3),
	(27, 'Financing', 3),
	(28, 'Registration', 3),
	(29, 'Service', 4),
	(30, 'Motorbikes', 4),
	(31, 'Merchandise/MRP', 4),
	(32, 'Downpayment', 4),
	(33, 'Reservation', 4),
	(34, 'Shipping & Handling', 4),
	(35, 'Towing Fee', 4),
	(36, 'Financing', 4),
	(37, 'Registration', 4),
	(38, 'Service', 5),
	(39, 'Motorbikes', 5),
	(40, 'Merchandise/MRP', 5),
	(41, 'Downpayment', 5),
	(42, 'Reservation', 5),
	(43, 'Shipping & Handling', 5),
	(44, 'Towing Fee', 5),
	(45, 'Financing', 5),
	(46, 'Registration', 5),
	(47, 'Freebies', 6),
	(48, 'Warranty', 6),
	(49, 'Marketing Expense', 6),
	(50, 'Operating Expense', 6),
	(51, 'AR - Employees', 6),
	(52, 'Cash Collection', 6),
	(53, 'Cash', 7);
/*!40000 ALTER TABLE `tblpaymenttype` ENABLE KEYS */;


-- Dumping structure for table invndc.tblposition
DROP TABLE IF EXISTS `tblposition`;
CREATE TABLE IF NOT EXISTS `tblposition` (
  `idPosition` int(3) DEFAULT NULL,
  `position` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblposition: ~9 rows (approximately)
/*!40000 ALTER TABLE `tblposition` DISABLE KEYS */;
INSERT INTO `tblposition` (`idPosition`, `position`) VALUES
	(1, 'Administrator'),
	(2, 'Sales & Mrktg Associate'),
	(3, 'Inventory Clerk'),
	(4, 'Developer'),
	(5, 'MRP / Inventory'),
	(6, 'Manager'),
	(7, 'Service In-Charge'),
	(8, 'Logistics'),
	(9, 'Business Development'),
	(10, 'Mechanic'),
	(11, 'Chief Mechanic'),
	(12, 'Sales Department'),
	(13, 'Branch Manager');
/*!40000 ALTER TABLE `tblposition` ENABLE KEYS */;


-- Dumping structure for table invndc.tblprivilege
DROP TABLE IF EXISTS `tblprivilege`;
CREATE TABLE IF NOT EXISTS `tblprivilege` (
  `id` int(2) DEFAULT NULL,
  `privilege` varchar(50) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblprivilege: 5 rows
/*!40000 ALTER TABLE `tblprivilege` DISABLE KEYS */;
INSERT INTO `tblprivilege` (`id`, `privilege`) VALUES
	(1, 'Administrator'),
	(2, 'Inventory'),
	(3, 'Sales'),
	(4, 'Servicing'),
	(5, 'MRP');
/*!40000 ALTER TABLE `tblprivilege` ENABLE KEYS */;


-- Dumping structure for table invndc.tblprovince
DROP TABLE IF EXISTS `tblprovince`;
CREATE TABLE IF NOT EXISTS `tblprovince` (
  `province` varchar(30) DEFAULT NULL,
  `regions` varchar(20) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblprovince: 11 rows
/*!40000 ALTER TABLE `tblprovince` DISABLE KEYS */;
INSERT INTO `tblprovince` (`province`, `regions`) VALUES
	('Misamis Oriental', 'X'),
	('Zamboanga del Sur', 'IX'),
	('Cebu', 'VII'),
	('Bukidnon', 'X'),
	('Zamboanga Sibugay', 'IX'),
	('Lanao del Norte', 'X'),
	('South Cotabato', 'ARMM'),
	('Metro Manila', 'NCR'),
	('Luzon', 'NCR'),
	('Sibugay', 'IX'),
	('Zamboanga Del Norte', 'IX');
/*!40000 ALTER TABLE `tblprovince` ENABLE KEYS */;


-- Dumping structure for table invndc.tblpullout
DROP TABLE IF EXISTS `tblpullout`;
CREATE TABLE IF NOT EXISTS `tblpullout` (
  `idPullOut` int(15) DEFAULT NULL,
  `pulloutID` varchar(15) DEFAULT NULL,
  `datePullOut` date DEFAULT NULL,
  `origin` varchar(15) DEFAULT NULL,
  `destination` varchar(15) DEFAULT NULL,
  `attention` varchar(300) DEFAULT NULL,
  `purpose` varchar(300) DEFAULT NULL,
  `preparedBy` varchar(50) DEFAULT NULL,
  `approvedBy` varchar(50) DEFAULT NULL,
  `receivedBy` varchar(50) DEFAULT NULL,
  `status` varchar(25) DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblpullout: 1 rows
/*!40000 ALTER TABLE `tblpullout` DISABLE KEYS */;
INSERT INTO `tblpullout` (`idPullOut`, `pulloutID`, `datePullOut`, `origin`, `destination`, `attention`, `purpose`, `preparedBy`, `approvedBy`, `receivedBy`, `status`, `remarks`) VALUES
	(1, '2015-1', '2015-11-18', 'NDC-ZBO', 'CDO', 'IOP/MHP', 'Unit transfer ', 'Girlie G. Tolosa', 'Darylle B. Battad', '', 'pending', 'for cdo prospect buyer as per DBB/AVL ');
/*!40000 ALTER TABLE `tblpullout` ENABLE KEYS */;


-- Dumping structure for table invndc.tblpulloutbikes
DROP TABLE IF EXISTS `tblpulloutbikes`;
CREATE TABLE IF NOT EXISTS `tblpulloutbikes` (
  `idPOB` int(15) NOT NULL DEFAULT '0',
  `idItem` int(15) DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `idPOI` int(15) DEFAULT NULL,
  `idPullOut` int(15) DEFAULT NULL,
  `pulloutID` varchar(50) DEFAULT NULL,
  `status` varchar(25) DEFAULT NULL,
  `remarks` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`idPOB`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblpulloutbikes: 0 rows
/*!40000 ALTER TABLE `tblpulloutbikes` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblpulloutbikes` ENABLE KEYS */;


-- Dumping structure for table invndc.tblpulloutitems
DROP TABLE IF EXISTS `tblpulloutitems`;
CREATE TABLE IF NOT EXISTS `tblpulloutitems` (
  `idPOI` int(25) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `qty` int(5) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `unitPrice` double(15,2) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `status` varchar(25) DEFAULT NULL,
  `remarks` varchar(100) DEFAULT NULL,
  `idPullOut` int(15) DEFAULT NULL,
  `pulloutID` varchar(15) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblpulloutitems: 1 rows
/*!40000 ALTER TABLE `tblpulloutitems` DISABLE KEYS */;
INSERT INTO `tblpulloutitems` (`idPOI`, `idItem`, `qty`, `unit`, `unitPrice`, `amount`, `status`, `remarks`, `idPullOut`, `pulloutID`) VALUES
	(1, 1415, 1, 'Unit(s)', 650000.00, 650000.00, 'pending', 'pullout', 1, '2015-1');
/*!40000 ALTER TABLE `tblpulloutitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tblqcharges
DROP TABLE IF EXISTS `tblqcharges`;
CREATE TABLE IF NOT EXISTS `tblqcharges` (
  `idCharges` int(3) unsigned NOT NULL AUTO_INCREMENT,
  `details` varchar(100) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `idQtrans` int(11) NOT NULL,
  `qno` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idCharges`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblqcharges: 0 rows
/*!40000 ALTER TABLE `tblqcharges` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblqcharges` ENABLE KEYS */;


-- Dumping structure for table invndc.tblqtrans
DROP TABLE IF EXISTS `tblqtrans`;
CREATE TABLE IF NOT EXISTS `tblqtrans` (
  `idQtrans` int(10) NOT NULL DEFAULT '0',
  `qno` varchar(10) DEFAULT NULL,
  `itemName` varchar(150) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `ciwaog` double(15,2) DEFAULT NULL,
  `ciwoaog` double(15,2) DEFAULT NULL,
  `preparedBy` varchar(25) DEFAULT NULL,
  `conforme` varchar(25) DEFAULT NULL,
  `dateTrans` date DEFAULT NULL,
  `insurance` varchar(50) DEFAULT NULL,
  `insuExpiry` date DEFAULT NULL,
  `idMtrbikes` int(10) DEFAULT NULL,
  PRIMARY KEY (`idQtrans`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblqtrans: 0 rows
/*!40000 ALTER TABLE `tblqtrans` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblqtrans` ENABLE KEYS */;


-- Dumping structure for table invndc.tblquotation
DROP TABLE IF EXISTS `tblquotation`;
CREATE TABLE IF NOT EXISTS `tblquotation` (
  `qno` varchar(10) DEFAULT NULL,
  `dateQuotation` date DEFAULT NULL,
  `dateValid` date DEFAULT NULL,
  `billTo` int(11) DEFAULT NULL,
  `dateInquiry` date DEFAULT NULL,
  `idTrans` int(2) DEFAULT NULL,
  `idTransType` int(2) DEFAULT NULL,
  `transTerm` varchar(15) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `soID` varchar(15) DEFAULT NULL,
  `salesInvc` varchar(25) DEFAULT NULL,
  `salesOR` varchar(25) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblquotation: 0 rows
/*!40000 ALTER TABLE `tblquotation` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblquotation` ENABLE KEYS */;


-- Dumping structure for table invndc.tblregion
DROP TABLE IF EXISTS `tblregion`;
CREATE TABLE IF NOT EXISTS `tblregion` (
  `region` varchar(20) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblregion: 8 rows
/*!40000 ALTER TABLE `tblregion` DISABLE KEYS */;
INSERT INTO `tblregion` (`region`) VALUES
	('X'),
	('XI'),
	('XII'),
	('XIII'),
	('ARMM'),
	('VII'),
	('IX'),
	('NCR');
/*!40000 ALTER TABLE `tblregion` ENABLE KEYS */;


-- Dumping structure for table invndc.tblreserveitems
DROP TABLE IF EXISTS `tblreserveitems`;
CREATE TABLE IF NOT EXISTS `tblreserveitems` (
  `idRsrvItem` int(15) NOT NULL AUTO_INCREMENT,
  `idItem` int(15) DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `itemName` varchar(250) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `qty` int(5) DEFAULT NULL,
  `unitPrice` double(12,2) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `remarks` text,
  `idRsrv` int(10) DEFAULT NULL,
  `rsrvNo` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idRsrvItem`)
) ENGINE=MyISAM AUTO_INCREMENT=43 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblreserveitems: 40 rows
/*!40000 ALTER TABLE `tblreserveitems` DISABLE KEYS */;
INSERT INTO `tblreserveitems` (`idRsrvItem`, `idItem`, `idMtrbikes`, `itemName`, `unit`, `qty`, `unitPrice`, `amount`, `status`, `remarks`, `idRsrv`, `rsrvNo`) VALUES
	(2, 0, 0, 'Downpayment for Rc200 black/2015', '', 0, 0.00, 26000.00, 'AR', '', 1, '2015-1'),
	(3, 0, 0, 'Handling, Lto, Ctpl', '', 0, 0.00, 18630.00, 'AR', '', 1, '2015-1'),
	(4, 0, 0, 'Compre Insurance', '', 0, 0.00, 12518.75, 'AR', '', 1, '2015-1'),
	(5, 0, 0, 'Downpayment 8/10 Ducati Hyper', '', 0, 0.00, 20000.00, 'AR', '', 2, '2015-2'),
	(6, 0, 0, 'Partial Payment Ducati Hyper', '', 0, 0.00, 398950.00, 'AR', '', 2, '2015-2'),
	(7, 0, 0, 'Handling, Lto, Ctpl', '', 0, 0.00, 21100.00, 'AR', '', 2, '2015-2'),
	(8, 0, 0, 'Compre Insurance', '', 0, 0.00, 43275.00, 'AR', '', 2, '2015-2'),
	(9, 0, 0, 'Reservation Italjet Formula 125', '', 0, 0.00, 51000.00, 'AR', '', 3, '2015-3'),
	(10, 0, 0, 'Handling, Lto, Ctpl', '', 0, 0.00, 11000.00, 'AR', '', 4, '2015-4'),
	(11, 0, 0, 'Handling, Lto', '', 0, 0.00, 6500.00, 'AR', '', 5, '2015-5'),
	(12, 0, 0, 'Reservation Ktm Rc200', '', 0, 0.00, 100000.00, 'AR', '', 6, '2015-6'),
	(13, 0, 0, 'Full Payment D Hyperstrada 821 Red', '', 0, 0.00, 420050.00, 'AR', '', 7, '2015-7'),
	(20, 0, 0, 'Lto, Ctp and Handling', '', 0, 0.00, 18630.00, 'AR', '', 13, '2015-13'),
	(15, 0, 0, 'Lto and Ctpl', '', 0, 0.00, 6800.00, 'AR', '', 9, '2015-9'),
	(16, 0, 0, 'Compre Insurance', '', 0, 0.00, 36200.00, 'AR', '', 9, '2015-9'),
	(17, 0, 0, 'Full Payment Yamaha FZ09', '', 0, 0.00, 420000.00, 'AR', '', 10, '2015-10'),
	(18, 0, 0, 'Downpayment of Ktm RC 200', '', 0, 0.00, 92000.00, 'AR', '', 11, '2015-11'),
	(19, 0, 30, 'Downpayment for Yamaha FZ09', '', 0, 0.00, 200000.00, 'AR', '', 12, '2015-12'),
	(21, 0, 0, 'Downpament 08/27/15 RC 200', '', 0, 0.00, 100000.00, 'AR', '', 14, '2015-14'),
	(22, 0, 0, 'MFR- 2015 Registration Fee', '', 0, 0.00, 3000.00, 'AR', '', 15, '2015-15'),
	(23, 0, 0, 'Other Charges - LTO/CTPL/HANDLING', '', 0, 0.00, 10330.00, 'AR', '', 16, '2015-16'),
	(24, 0, 0, 'Lto, Ctpl and Handling', '', 0, 0.00, 13630.00, 'AR', '', 17, '2015-17'),
	(25, 0, 0, 'MFR IV -  2015 Registration', '', 0, 0.00, 3000.00, 'AR', '', 18, '2015-18'),
	(26, 0, 0, 'MFR IV -  2015 Registration', '', 0, 0.00, 3000.00, 'AR', '', 19, '2015-19'),
	(27, 0, 0, 'MFR IV 2015 - Registration', '', 0, 0.00, 3000.00, 'AR', '', 20, '2015-20'),
	(28, 0, 0, 'Lto, Ctpl and Handling ', '', 0, 0.00, 11630.00, 'AR', '', 21, '2015-21'),
	(29, 0, 6, 'Add ons: LTO/CTPL/Handling C#0964', 'Unit(s)', 0, 399000.00, 21100.00, 'AR', '', 22, '2015-22'),
	(30, 0, 6, 'Add ons: LTO/CTPL/Handling C#0965', '', 0, 0.00, 21100.00, 'AR', '', 23, '2015-23'),
	(31, 0, 32, 'Add ons: Handling', 'Unit(s)', 0, 0.00, 2500.00, 'AR', '', 24, '2015-24'),
	(32, 0, 32, 'Full payment of Italjet Formula 125', 'Unit(s)', 0, 0.00, 50000.00, 'AR', '', 25, '2015-25'),
	(33, 0, 0, 'DPF', '', 0, 0.00, 14925.00, 'AR', '', 26, '2015-26'),
	(34, 0, 0, 'Handling', '', 0, 0.00, 2500.00, 'AR', '', 26, '2015-26'),
	(35, 0, 0, 'Lto Registration', '', 0, 0.00, 2500.00, 'AR', '', 26, '2015-26'),
	(36, 0, 0, 'Comprehensive Insurance', '', 0, 0.00, 12500.00, 'AR', '', 26, '2015-26'),
	(37, 0, 0, 'Lto Reg', '', 0, 0.00, 4000.00, 'AR', '', 27, '2015-27'),
	(38, 0, 0, 'Ctpl', '', 0, 0.00, 330.00, 'AR', '', 27, '2015-27'),
	(39, 0, 0, 'Handling', '', 0, 0.00, 14300.00, 'AR', '', 27, '2015-27'),
	(40, 0, 0, 'Full payment for italjet dated 11/06/15', '', 0, 0.00, 50000.00, 'AR', '', 28, '2015-28'),
	(41, 0, 0, 'Reservation Fee - Kawasaki Ninja 1000 Grey 2016', '', 0, 0.00, 30000.00, 'AR', '', 29, '2015-29'),
	(42, 0, 0, 'Downpayment - Kawasaki Ninja 1000 Gray 2016', '', 0, 0.00, 100000.00, 'AR', '', 30, '2015-30');
/*!40000 ALTER TABLE `tblreserveitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tblreserveorder
DROP TABLE IF EXISTS `tblreserveorder`;
CREATE TABLE IF NOT EXISTS `tblreserveorder` (
  `idRsrv` int(10) NOT NULL DEFAULT '0',
  `rsrvNo` varchar(15) DEFAULT NULL,
  `dateRsrv` date DEFAULT NULL,
  `idCustomer` int(10) DEFAULT NULL,
  `recievedBy` varchar(50) DEFAULT NULL,
  `payMode` varchar(60) DEFAULT NULL,
  `type` varchar(50) DEFAULT NULL,
  `term` varchar(60) DEFAULT NULL,
  `checkNo` varchar(30) DEFAULT NULL,
  `downpayment` double(15,2) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `remarks` text,
  `id` int(15) DEFAULT NULL,
  `soID` varchar(25) DEFAULT NULL,
  PRIMARY KEY (`idRsrv`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblreserveorder: 29 rows
/*!40000 ALTER TABLE `tblreserveorder` DISABLE KEYS */;
INSERT INTO `tblreserveorder` (`idRsrv`, `rsrvNo`, `dateRsrv`, `idCustomer`, `recievedBy`, `payMode`, `type`, `term`, `checkNo`, `downpayment`, `status`, `remarks`, `id`, `soID`) VALUES
	(1, '2015-1', '2015-08-08', 89, 'Jennifer P. Dantes', 'Cash (Sales)', NULL, '', '0', 57148.75, 'AR', 'Rc200 Non Abs 2015/black', 0, '0'),
	(2, '2015-2', '2015-08-27', 46, 'Jennifer P. Dantes', 'Check', NULL, '', '0', 483325.00, 'AR', 'Check/AR#1975 not included 20k', 0, '0'),
	(3, '2015-3', '2015-08-08', 90, 'Jennifer P. Dantes', 'Check', NULL, '', '0', 51000.00, 'AR', '', 0, '0'),
	(4, '2015-4', '2015-08-11', 90, 'Jennifer P. Dantes', 'Check', NULL, '', '0', 11000.00, 'AR', '', 0, '0'),
	(5, '2015-5', '2015-08-24', 91, 'Jennifer P. Dantes', 'Cash (Sales)', NULL, '', '0', 6500.00, 'AR', '', 0, '0'),
	(6, '2015-6', '2015-08-27', 29, 'Jennifer P. Dantes', 'Cash (Sales)', NULL, '', '0', 100000.00, 'AR', '', 0, '0'),
	(7, '2015-7', '2015-08-27', 29, 'Jennifer P. Dantes', 'Check', NULL, '', '0', 420050.00, 'AR', '', 0, '0'),
	(13, '2015-13', '2015-09-21', 93, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Other charges of RC200 - Mr. Asarul', 0, '0'),
	(9, '2015-9', '2015-09-01', 98, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Other chargers for Yamaha FZ 09', 0, '0'),
	(10, '2015-10', '2015-09-01', 98, 'Girlie G. Tolosa', 'Check', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(11, '2015-11', '2015-09-19', 93, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(12, '2015-12', '2015-09-01', 109, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(14, '2015-14', '2015-09-21', 93, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(15, '2015-15', '2015-10-05', 23, 'Joseph V. Del Rosario Jr.', 'Check', NULL, '', '961', 0.00, 'AR', 'MFR - IV 2015 Registration Fee', 0, '0'),
	(16, '2015-16', '2015-10-06', 121, 'Joseph V. Del Rosario Jr.', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Add ons for KTM RC 200', 0, '0'),
	(17, '2015-17', '2015-10-16', 126, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Other Charges of Rc200', 0, '0'),
	(18, '2015-18', '2015-10-22', 3, 'Joseph V. Del Rosario Jr.', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'MFR IV -  2015 Registration', 0, '0'),
	(19, '2015-19', '2015-10-22', 130, 'Joseph V. Del Rosario Jr.', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'MFR IV -  2015 Registration', 0, '0'),
	(20, '2015-20', '2015-10-22', 131, 'Joseph V. Del Rosario Jr.', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'MFR IV -  2015 Registration', 0, '0'),
	(21, '2015-21', '2015-10-22', 132, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(22, '2015-22', '2015-10-26', 134, 'Joseph V. Del Rosario Jr.', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(23, '2015-23', '2015-10-26', 134, 'Joseph V. Del Rosario Jr.', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(24, '2015-24', '2015-11-06', 92, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Add ons of Italjet Formula 125: Lto - free and Ctpl - free', 0, '0'),
	(25, '2015-25', '2015-11-06', 92, 'Girlie G. Tolosa', 'Charge (Accounts Receivable)', NULL, '', '', 0.00, 'AR', 'PDC - 1 month as per approved AVL', 0, '0'),
	(26, '2015-26', '2015-11-11', 140, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Other Charges for RC200 - Mr. Salim', 0, '0'),
	(27, '2015-27', '2015-11-28', 144, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', 'Other Charges of Duke 200 Non-Abs Orange 2014 c#3656', 0, '0'),
	(28, '2015-28', '2015-12-07', 92, 'Girlie G. Tolosa', 'Check', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(29, '2015-29', '2015-12-11', 147, 'Girlie G. Tolosa', 'Cash (Sales)', NULL, '', '0', 0.00, 'AR', '', 0, '0'),
	(30, '2015-30', '2015-12-17', 147, 'Girlie G. Tolosa', 'Cash ', 'Sales', '', '', 0.00, 'AR', '', 0, '0');
/*!40000 ALTER TABLE `tblreserveorder` ENABLE KEYS */;


-- Dumping structure for table invndc.tblrptcost
DROP TABLE IF EXISTS `tblrptcost`;
CREATE TABLE IF NOT EXISTS `tblrptcost` (
  `idItem` int(15) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `dateBeg` date DEFAULT NULL,
  `dateRcvd` date DEFAULT NULL,
  `qtyBeg` int(5) DEFAULT NULL,
  `costBeg` double(18,2) DEFAULT NULL,
  `qtyRcvd` int(5) DEFAULT NULL,
  `costRcvd` double(18,2) DEFAULT NULL,
  `invBeg` int(10) DEFAULT NULL,
  `invIn` int(10) DEFAULT NULL,
  `invOut` int(10) DEFAULT NULL,
  `invEnd` int(10) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblrptcost: 65 rows
/*!40000 ALTER TABLE `tblrptcost` DISABLE KEYS */;
INSERT INTO `tblrptcost` (`idItem`, `code`, `dateBeg`, `dateRcvd`, `qtyBeg`, `costBeg`, `qtyRcvd`, `costRcvd`, `invBeg`, `invIn`, `invOut`, `invEnd`) VALUES
	(1236, 1236, '2015-01-14', '0000-00-00', 0, 1920.00, 0, 0.00, 0, 3, 3, 0),
	(1331, 1331, '0000-00-00', '2014-11-08', 50, 289.00, 50, 0.00, 24, 98, 140, -18),
	(1331, 1331, '0000-00-00', '2014-11-08', 50, 289.00, 50, 0.00, 24, 98, 140, -18),
	(1331, 1331, '0000-00-00', '2014-11-08', 50, 289.00, 50, 0.00, 24, 98, 140, -18),
	(1374, 1374, '0000-00-00', '2014-11-29', 0, 380.00, 12, 380.00, 0, 88, 50, 38),
	(1374, 1374, '0000-00-00', '2014-11-29', 0, 380.00, 12, 380.00, 0, 88, 50, 38),
	(1391, 1391, '2014-11-14', '2014-11-14', 0, 1472.00, 1, 1472.00, 0, 2, 2, 0),
	(1423, 1423, '2014-12-04', '2014-12-04', 0, 27.50, 500, 27.50, 752, 248, 299, 701),
	(1431, 1431, '2014-12-03', '2014-12-03', 0, 112.46, 13, 112.46, 0, 11, 4, 7),
	(1432, 1432, '2014-12-03', '2014-12-03', 0, 112.46, 29, 112.46, 0, 14, 5, 9),
	(1580, 1580, '2015-01-07', '2015-01-07', 0, 1785.71, 2, 1785.71, 0, 2, 2, 0),
	(1591, 1591, '2015-01-16', '2015-01-16', 0, 295.00, 20, 295.00, 0, 47, 10, 37),
	(1609, 1609, '2015-01-16', '2015-01-16', 0, 210.00, 3, 210.00, 0, 3, 3, 0),
	(1611, 1611, '2015-01-16', '2015-01-16', 0, 210.00, 3, 210.00, 0, 4, 4, 0),
	(1611, 1611, '2015-01-16', '2015-01-16', 0, 210.00, 3, 210.00, 0, 4, 4, 0),
	(1680, 1680, '2015-02-10', '2015-02-10', 0, 450.00, 60, 450.00, 0, 20, 3, 17),
	(1684, 1684, '2015-02-11', '2015-02-11', 0, 450.00, 20, 450.00, 0, 6, 6, 0),
	(1685, 1685, '2015-02-11', '2015-02-11', 0, 450.00, 10, 450.00, 0, 9, 1, 8),
	(1703, 1703, '2015-03-11', '2015-03-11', 0, 140.90, 20, 140.90, 0, 20, 1, 19),
	(1704, 1704, '2015-03-16', '2015-03-16', 0, 561.00, 1, 0.00, 0, 7, 2, 5),
	(1704, 1704, '2015-03-16', '2015-03-16', 0, 561.00, 1, 0.00, 0, 7, 2, 5),
	(1724, 1724, '2015-04-01', '2015-04-01', 0, 0.00, 1, 0.00, 0, 1, 1, 0),
	(1729, 1729, '2015-04-17', '2015-04-17', 0, 8160.00, 2, 8160.00, 0, 3, 0, 3),
	(1734, 1734, '2015-04-17', '2015-04-17', 0, 1721.25, 1, 1721.25, 0, 2, 1, 1),
	(1739, 1739, '2015-04-27', '2015-04-27', 0, 292.00, 1, 292.00, 0, 2, 2, 0),
	(1742, 1742, '2015-04-27', '2015-04-27', 0, 3200.00, 1, 3200.00, 0, 1, 1, 0),
	(1125, 1125, '2015-10-01', '0000-00-00', 5, 328.84, 10, 328.84, 0, 19, 8, 11),
	(1832, 1832, '0000-00-00', '0000-00-00', 0, 4400.00, 1, 4400.00, 0, 1, 1, 0),
	(1833, 1833, '0000-00-00', '0000-00-00', 0, 4400.00, 1, 4400.00, 0, 1, 1, 0),
	(1835, 1835, '0000-00-00', '0000-00-00', 0, 50.00, 5, 50.00, 0, 5, 2, 3),
	(1841, 1841, '0000-00-00', '0000-00-00', 0, 9190.00, 1, 9190.00, 0, 1, 1, 0),
	(1331, 1331, '0000-00-00', '0000-00-00', 50, 289.00, 0, 405.00, 24, 98, 140, -18),
	(1331, 1331, '0000-00-00', '0000-00-00', 50, 289.00, 0, 405.00, 24, 98, 140, -18),
	(1331, 1331, '0000-00-00', '0000-00-00', 50, 289.00, 0, 405.00, 24, 98, 140, -18),
	(1854, 1854, '2015-06-08', '2015-06-08', 0, 405.00, 10, 405.00, 0, 10, 3, 7),
	(1704, 1704, '2015-03-16', '2015-06-08', 0, 561.00, 6, 561.00, 0, 7, 2, 5),
	(1704, 1704, '2015-03-16', '2015-06-08', 0, 561.00, 6, 561.00, 0, 7, 2, 5),
	(1856, 1856, '2015-06-11', '2015-06-08', 0, 1800.00, 1, 1800.00, 0, 1, 1, 0),
	(7, 7, '2015-10-01', '0000-00-00', 0, 0.00, 0, 0.00, 1, 0, 4, -3),
	(162, 162, '2015-10-01', '0000-00-00', 1, 1071.43, 0, 0.00, 1, 0, 1, 0),
	(294, 294, '2015-10-01', '0000-00-00', 4, 3017.86, 0, 0.00, 4, 0, 1, 3),
	(429, 429, '2015-10-01', '0000-00-00', 1, 4620.54, 0, 0.00, 1, 0, 1, 0),
	(479, 479, '2015-10-01', '0000-00-00', 1, 375.00, 0, 0.00, 1, 0, 2, -1),
	(480, 480, '2015-10-01', '0000-00-00', 4, 321.43, 0, 0.00, 4, 0, 3, 1),
	(494, 494, '2015-10-01', '0000-00-00', 10, 0.00, 0, 0.00, 10, 2, 8, 4),
	(494, 494, '2015-10-01', '0000-00-00', 10, 0.00, 0, 0.00, 10, 2, 8, 4),
	(580, 580, '2015-10-01', '0000-00-00', 1, 1414.29, 0, 0.00, 1, 0, 1, 0),
	(583, 583, '2015-10-01', '0000-00-00', 2, 589.29, 0, 0.00, 2, 0, 2, 0),
	(661, 661, '2015-10-01', '0000-00-00', 0, 0.00, 0, 0.00, 0, 1, 1, 0),
	(704, 704, '2015-10-01', '0000-00-00', 51, 3.38, 0, 0.00, 51, 0, 5, 46),
	(722, 722, '2015-10-01', '0000-00-00', 10, 321.43, 0, 0.00, 10, 2, 4, 8),
	(942, 942, '2015-10-01', '0000-00-00', 0, 2139.29, 0, 0.00, 0, 1, 1, 0),
	(1129, 1129, '2015-10-01', '0000-00-00', 24, 378.57, 0, 0.00, 24, 15, 12, 27),
	(1199, 1199, '2014-10-23', '0000-00-00', 0, 112.46, 0, 0.00, 0, 15, 6, 9),
	(1202, 1202, '2014-10-23', '0000-00-00', 0, 112.46, 0, 0.00, 0, 20, 5, 15),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1802, 1802, '2015-05-16', '0000-00-00', 0, 150.00, 0, 0.00, 0, 100, 19, 81),
	(1848, 1848, '2015-05-16', '0000-00-00', 0, 1250.00, 0, 0.00, 0, 2, 2, 0),
	(1848, 1848, '2015-05-16', '0000-00-00', 0, 1250.00, 0, 0.00, 0, 2, 2, 0),
	(1848, 1848, '2015-05-16', '0000-00-00', 0, 1250.00, 0, 0.00, 0, 2, 2, 0);
/*!40000 ALTER TABLE `tblrptcost` ENABLE KEYS */;


-- Dumping structure for table invndc.tblrptcostbeg
DROP TABLE IF EXISTS `tblrptcostbeg`;
CREATE TABLE IF NOT EXISTS `tblrptcostbeg` (
  `idItem` int(15) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `itemName` varchar(200) DEFAULT NULL,
  `partNo` varchar(50) DEFAULT NULL,
  `brand` varchar(100) DEFAULT NULL,
  `category` varchar(100) DEFAULT NULL,
  `dateBeg` date DEFAULT NULL,
  `qtyBeg` int(5) DEFAULT NULL,
  `costBeg` double(18,2) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblrptcostbeg: 0 rows
/*!40000 ALTER TABLE `tblrptcostbeg` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblrptcostbeg` ENABLE KEYS */;


-- Dumping structure for table invndc.tblrptcostout
DROP TABLE IF EXISTS `tblrptcostout`;
CREATE TABLE IF NOT EXISTS `tblrptcostout` (
  `idItem` int(15) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `dateOut` date DEFAULT NULL,
  `qtyOut` int(10) DEFAULT NULL,
  `costOut` double(18,2) DEFAULT NULL,
  `soID` varchar(20) DEFAULT NULL,
  `salesInvc` int(20) DEFAULT NULL,
  `salesOR` int(20) DEFAULT NULL,
  `id` int(20) DEFAULT NULL,
  `idSales` int(20) DEFAULT NULL,
  `idPullOut` int(20) DEFAULT NULL,
  `pulloutID` varchar(20) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblrptcostout: 0 rows
/*!40000 ALTER TABLE `tblrptcostout` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblrptcostout` ENABLE KEYS */;


-- Dumping structure for table invndc.tblrptcostrcv
DROP TABLE IF EXISTS `tblrptcostrcv`;
CREATE TABLE IF NOT EXISTS `tblrptcostrcv` (
  `idItem` int(15) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `dateRcvd` date DEFAULT NULL,
  `qtyRcvd` int(10) DEFAULT NULL,
  `costRcvd` double(18,2) DEFAULT NULL,
  `roid` varchar(20) DEFAULT NULL,
  `idOrder` int(15) DEFAULT NULL,
  `pk` int(15) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblrptcostrcv: 0 rows
/*!40000 ALTER TABLE `tblrptcostrcv` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblrptcostrcv` ENABLE KEYS */;


-- Dumping structure for table invndc.tblrptcostsales
DROP TABLE IF EXISTS `tblrptcostsales`;
CREATE TABLE IF NOT EXISTS `tblrptcostsales` (
  `idItem` int(15) DEFAULT NULL,
  `code` int(15) DEFAULT NULL,
  `partNum` varchar(30) DEFAULT NULL,
  `itemName` varchar(500) DEFAULT NULL,
  `category` varchar(50) DEFAULT NULL,
  `brandName` varchar(50) DEFAULT NULL,
  `unit` varchar(30) DEFAULT NULL,
  `qtySold` int(10) DEFAULT NULL,
  `dateSold` date DEFAULT NULL,
  `cost` double(18,2) DEFAULT NULL,
  `srp` double(18,2) DEFAULT NULL,
  `itemDscnt` int(5) DEFAULT NULL,
  `totalDscnt` int(5) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblrptcostsales: 60 rows
/*!40000 ALTER TABLE `tblrptcostsales` DISABLE KEYS */;
INSERT INTO `tblrptcostsales` (`idItem`, `code`, `partNum`, `itemName`, `category`, `brandName`, `unit`, `qtySold`, `dateSold`, `cost`, `srp`, `itemDscnt`, `totalDscnt`) VALUES
	(7, 7, '\r', 'YAMAHA TENERE 1200 2013 - GRAY/BLACK\r\n', 'Motorbikes', 'Yamaha', 'Unit(s)', 1, '2015-06-11', 0.00, 55000.00, 0, 0),
	(162, 162, '44440291C\r', 'OIL FILTER DUCATI 1199 PANIGALE - 44440291C', 'Parts & Accessories', 'DUCATI', 'Pc(s)', 1, '2015-06-02', 1071.43, 1970.00, 0, 0),
	(294, 294, '50313030200\r', 'BRAKE PAD TT2701HH-FRONT SET - 50313030200', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-09', 3017.86, 5200.00, 0, 0),
	(429, 429, '5.48E+12\r', 'HANDLEBAR KTM - 5480200130030', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-24', 4620.54, 6900.00, 0, 0),
	(479, 479, '58038005100\r', 'OIL FILTER - 690 - END SMC LONG - 58038005100', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-08', 375.00, 700.00, 0, 0),
	(480, 480, '75038046100\r', 'OIL FILTER 690DUKE 13 SHORT - 75038046100', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-08', 321.43, 600.00, 0, 0),
	(494, 494, '\r', 'O-RING KTM', 'Parts & Accessories', 'KTM', 'Pc(s)', 2, '2015-06-08', 0.00, 100.00, 0, 0),
	(494, 494, '\r', 'O-RING KTM', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-13', 0.00, 100.00, 0, 0),
	(580, 580, '54814026200\r', 'SIGNAL LIGHT FRONT RS-REAR LS - 54814026200', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-04', 1414.29, 2135.00, 0, 0),
	(583, 583, '60114025000\r', 'SIGNAL LIGHT-FRONT L/S REAR R/S - 60114025000', 'Parts & Accessories', 'KTM', 'Pc(s)', 2, '2015-06-19', 589.29, 1100.00, 0, 0),
	(661, 661, '\r', 'LX-LT REAR RACK - CHROME', 'Parts & Accessories', 'Piaggio', 'Pc(s)', 1, '2015-06-23', 0.00, 6500.00, 0, 0),
	(704, 704, '\r', 'KWIK PATCHES - PP0 SMALL', 'Parts & Accessories', 'Other', 'Pc(s)', 1, '2015-06-11', 3.38, 35.00, 0, 0),
	(722, 722, '\r', 'OIL FILTER EMGO - 10-82270', 'Parts & Accessories', 'Other', 'Pc(s)', 1, '2015-06-11', 321.43, 505.00, 0, 0),
	(942, 942, '3PW088623\r', 'POLO SHIRT GIRLS TEAM - MEDIUM - 3PW088623', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-27', 0.00, 3029.00, 0, 0),
	(1125, 1125, '\r', 'ADVANCE 4T AX7 - SEMI SYNTHETIC - 10W-40', 'Oils & Lubricants', 'Shell', 'Ltr(s)', 4, '2015-06-02', 328.84, 295.00, 0, 0),
	(1129, 1129, '\r', 'CASTROL POWER 1 10W-50 FULLY SYNTHETIC 4T', 'Oils & Lubricants', 'Castrol', 'Ltr(s)', 2, '2015-06-11', 378.57, 570.00, 0, 0),
	(1199, 1199, '', 'KTM CDO TSHIRT ORANGE - SMALL', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-08', 0.00, 550.00, 0, 0),
	(1202, 1202, '', 'KTM CDO TSHIRT ORANGE - XLARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-11', 0.00, 550.00, 0, 0),
	(1236, 1236, '', 'KYT VENOM RF2 - SOLID FIRE/RED/BLACK GLOSS - XL', 'Apparel & Merchandise', 'KYT', 'Pc(s)', 1, '2015-06-09', 0.00, 2690.00, 0, 0),
	(1331, 1331, '', 'CASTROL MAGNATEC 10w-40', 'Oils & Lubricants', 'Castrol', 'Ltr(s)', 4, '2015-06-06', 289.00, 405.00, 0, 0),
	(1331, 1331, '', 'CASTROL MAGNATEC 10w-40', 'Oils & Lubricants', 'Castrol', 'Ltr(s)', 7, '2015-06-24', 289.00, 405.00, 0, 0),
	(1331, 1331, '', 'CASTROL MAGNATEC 10w-40', 'Oils & Lubricants', 'Castrol', 'Ltr(s)', 7, '2015-06-26', 289.00, 405.00, 0, 0),
	(1374, 1374, '', 'MOTOREX FORMULA 4T SEMI 15W-50', 'Oils & Lubricants', 'Motorex', 'Ltr(s)', 2, '2015-06-08', 380.00, 595.00, 0, 0),
	(1374, 1374, '', 'MOTOREX FORMULA 4T SEMI 15W-50', 'Oils & Lubricants', 'Motorex', 'Ltr(s)', 2, '2015-06-13', 380.00, 595.00, 0, 0),
	(1391, 1391, '', 'KYT GALAXY SLIDE SOLID - BLACK MET/TITANIUM MATT', 'Apparel & Merchandise', 'KYT', 'Pc(s)', 1, '2015-06-27', 1472.00, 2580.00, 0, 10),
	(1423, 1423, '', 'KEYCHAIN - NORMINRING MOTORBIKES', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-10', 27.50, 27.50, 0, 0),
	(1431, 1431, '', 'NDC PREMIUM MULTIBRAND TSHIRT BLACK - XXLARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-10', 112.46, 112.46, 0, 0),
	(1432, 1432, '', 'NDC PREMIUM MULTIBRAND TSHIRT BLACK - LARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-04', 112.46, 112.46, 0, 0),
	(1580, 1580, '', 'POLO-SHIRT DUCATI COMPANY2 - L - 987690305', 'Apparel & Merchandise', 'DUCATI', 'Pc(s)', 1, '2015-06-13', 1785.71, 2525.00, 0, 20),
	(1591, 1591, '90138015000', 'OIL FILTER - DUKE 200 - 90138015000 - 021623', 'Parts & Accessories', 'KTM', 'Pc(s)', 1, '2015-06-13', 295.00, 600.00, 0, 0),
	(1609, 1609, '', 'KTM CAP - ORANGE/BLACK', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-20', 210.00, 460.00, 0, 0),
	(1611, 1611, '', 'KTM CAP - BLACK', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-22', 210.00, 460.00, 0, 0),
	(1611, 1611, '', 'KTM CAP - BLACK', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-26', 210.00, 460.00, 0, 0),
	(1680, 1680, '', 'KTM READY TO RACE TSHIRT ORANGE - LARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-01', 450.00, 800.00, 0, 0),
	(1684, 1684, '', 'KTM READY TO RACE TSHIRT BLACK - LARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-13', 450.00, 800.00, 0, 0),
	(1685, 1685, '', 'KTM READY TO RACE TSHIRT BLACK - XLARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-22', 450.00, 800.00, 0, 10),
	(1703, 1703, '', 'BIKE RALLY TSHIRT WHITE XXLARGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-10', 140.90, 140.90, 0, 0),
	(1704, 1704, '160970008', 'FILTER - ASSY - KAWASAKI', 'Parts & Accessories', 'Other', 'Pc(s)', 1, '2015-06-13', 0.00, 790.00, 0, 0),
	(1704, 1704, '160970008', 'FILTER - ASSY - KAWASAKI', 'Parts & Accessories', 'Other', 'Pc(s)', 1, '2015-06-15', 0.00, 790.00, 0, 0),
	(1724, 1724, '', 'R&G REAR PADDOCKS STAND', 'Parts & Accessories', 'Other', 'Pc(s)', 1, '2015-06-25', 0.00, 7310.00, 0, 0),
	(1729, 1729, '', 'PIRELLI MT 60 RS CORSA 160/60-17', 'Tires & Inner Tubes', 'Pirelli', 'Pc(s)', 1, '2015-06-01', 8160.00, 11220.00, 0, 0),
	(1734, 1734, '', 'SPYDER RECON P 100 MEDIUM SH.WHT - 12038462', 'Apparel & Merchandise', 'Spyder Helmets', 'Pc(s)', 1, '2015-06-25', 1721.25, 2410.00, 0, 0),
	(1739, 1739, '', 'KTM CAP BLACK - ORANGE', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-01', 292.00, 460.00, 0, 0),
	(1742, 1742, '', 'KTM RACING JACKET XXLARGE - 022505', 'Apparel & Merchandise', 'KTM', 'Pc(s)', 1, '2015-06-20', 3200.00, 5020.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Pc(s)', 1, '2015-06-02', 0.00, 150.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Unit(s)', 1, '2015-06-08', 0.00, 150.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Unit(s)', 1, '2015-06-09', 0.00, 150.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Unit(s)', 1, '2015-06-09', 0.00, 150.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Unit(s)', 1, '2015-06-11', 0.00, 150.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Unit(s)', 1, '2015-06-13', 0.00, 150.00, 0, 0),
	(1802, 1802, '', 'SERVICE SUPPLY (MISCELLANEOUS)', 'Other Services', 'Cash Collections', 'Unit(s)', 1, '2015-06-13', 0.00, 150.00, 0, 0),
	(1832, 1832, 'P1020405', 'VESPA LX 150 SIDE MIRROR P1020405', 'Parts & Accessories', 'DUCATI', 'Pc(s)', 1, '2015-06-23', 4400.00, 4400.00, 0, 0),
	(1833, 1833, 'P1020404', 'VESPA LX 150 SIDE MIRROR P1020404', 'Parts & Accessories', 'DUCATI', 'Pc(s)', 1, '2015-06-23', 4400.00, 4400.00, 0, 0),
	(1835, 1835, '0', 'KWIK PATCH MCX/MSX-10', 'Parts & Accessories', 'Other', 'Pc(s)', 1, '2015-06-09', 50.00, 50.00, 0, 0),
	(1841, 1841, '0', 'REVOLVER EVO SOLID MATTE BLACK - LARGE', 'Apparel & Merchandise', 'BELL Helmets', 'Pc(s)', 1, '2015-06-02', 9190.00, 9190.00, 0, 0),
	(1848, 1848, '', 'OTHERS', 'Other Services', 'Cash Collections', 'Pc(s)', 1, '2015-06-04', 0.00, 7370.00, 0, 0),
	(1848, 1848, '', 'OTHERS', 'Other Services', 'Cash Collections', 'Pc(s)', 1, '2015-06-01', 0.00, 2942.50, 0, 0),
	(1848, 1848, '', 'OTHERS', 'Other Services', 'Cash Collections', 'Pc(s)', 1, '2015-06-17', 0.00, 7500.00, 0, 0),
	(1854, 1854, '0', 'TOTAL ENGINE OIL FULLY SYNTH 10W-50', 'Oils & Lubricants', 'TOTAL', 'Ltr(s)', 3, '2015-06-13', 405.00, 495.00, 0, 0),
	(1856, 1856, 'CR0002BK', 'R&G SPOOL / COTTOL REEL SWINGARM', 'Parts & Accessories', 'Metzeler', 'Pc(s)', 1, '2015-06-25', 1800.00, 2520.00, 0, 0);
/*!40000 ALTER TABLE `tblrptcostsales` ENABLE KEYS */;


-- Dumping structure for table invndc.tblsales
DROP TABLE IF EXISTS `tblsales`;
CREATE TABLE IF NOT EXISTS `tblsales` (
  `idSales` int(15) NOT NULL AUTO_INCREMENT,
  `idItem` int(10) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `unitPrice` double(15,2) DEFAULT NULL,
  `cost` double(15,2) DEFAULT NULL,
  `discount` int(3) DEFAULT NULL,
  `amntDscnt` double(18,2) DEFAULT NULL,
  `amount` double(18,2) DEFAULT NULL,
  `id` int(15) DEFAULT NULL,
  `soID` varchar(25) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`idSales`)
) ENGINE=MyISAM AUTO_INCREMENT=240 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblsales: 204 rows
/*!40000 ALTER TABLE `tblsales` DISABLE KEYS */;
INSERT INTO `tblsales` (`idSales`, `idItem`, `unit`, `qty`, `unitPrice`, `cost`, `discount`, `amntDscnt`, `amount`, `id`, `soID`, `status`, `idMtrbikes`, `remarks`) VALUES
	(68, 537, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 43, '0', 'sold', 0, NULL),
	(7, 1095, 'Pc(s)', 1, 880.00, 0.00, 0, NULL, 880.00, 7, '2015-2', 'sold', 0, NULL),
	(67, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 43, '0', 'sold', 0, NULL),
	(66, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 43, '0', 'sold', 0, NULL),
	(65, 525, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 42, '0', 'sold', 0, NULL),
	(6, 1091, 'Pc(s)', 1, 435.00, 0.00, 0, NULL, 435.00, 6, '2015-1', 'sold', 0, NULL),
	(64, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 42, '0', 'sold', 0, NULL),
	(63, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 42, '0', 'sold', 0, NULL),
	(62, 155, 'Pc(s)', 1, 925.00, NULL, 0, NULL, 925.00, 40, '0', 'sold', 0, NULL),
	(60, 1371, 'Ltr(s)', 1, 655.00, NULL, 0, NULL, 655.00, 39, '0', 'sold', 0, NULL),
	(61, 1351, 'Ltr(s)', 3, 540.00, NULL, 0, NULL, 1620.00, 40, '0', 'sold', 0, NULL),
	(15, 1371, 'Ltr(s)', 2, 655.00, 0.00, 0, NULL, 1310.00, 14, '2015-3', 'sold', 0, NULL),
	(16, 726, 'Pc(s)', 1, 55.00, 0.00, 0, NULL, 55.00, 14, '2015-3', 'sold', 0, NULL),
	(17, 537, 'Pc(s)', 1, 660.00, 0.00, 0, NULL, 660.00, 14, '2015-3', 'sold', 0, NULL),
	(18, 1224, 'Pc(s)', 1, 2655.00, 0.00, 5, NULL, 2522.25, 15, '2015-4', 'sold', 0, NULL),
	(58, 22, 'Unit(s)', 1, 294000.00, 0.00, 0, NULL, 294000.00, 37, '0', 'sold', 3, ''),
	(59, 6, 'Unit(s)', 1, 839000.00, 0.00, 0, NULL, 839000.00, 38, '0', 'sold', 4, ''),
	(56, 13, 'Unit(s)', 1, 199000.00, 0.00, 0, NULL, 199000.00, 35, '0', 'sold', 1, ''),
	(57, 24, 'Unit(s)', 1, 105000.00, 0.00, 0, NULL, 105000.00, 36, '0', 'sold', 2, ''),
	(25, 1364, 'Ltr(s)', 1, 805.00, 0.00, 0, NULL, 805.00, 18, '2015-5', 'sold', 0, NULL),
	(26, 1375, 'Ltr(s)', 1, 585.00, 0.00, 0, NULL, 585.00, 18, '2015-5', 'sold', 0, NULL),
	(27, 1370, 'Ltr(s)', 2, 960.00, 0.00, 0, NULL, 1920.00, 18, '2015-5', 'sold', 0, NULL),
	(28, 799, 'Pc(s)', 1, 80.00, 0.00, 0, NULL, 80.00, 19, '2015-6', 'sold', 0, NULL),
	(29, 1362, 'ML', 1, 182.00, 0.00, 0, NULL, 182.00, 20, '2015-7', 'sold', 0, NULL),
	(30, 798, 'Pc(s)', 1, 80.00, 0.00, 0, NULL, 80.00, 21, '2015-8', 'sold', 0, NULL),
	(31, 797, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 22, '2015-9', 'sold', 0, NULL),
	(32, 793, 'Pc(s)', 1, 100.00, 0.00, 0, NULL, 100.00, 22, '2015-9', 'sold', 0, NULL),
	(33, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 22, '2015-9', 'sold', 0, NULL),
	(34, 1364, 'Ltr(s)', 1, 466.07, 0.00, 0, NULL, 466.07, 23, '2015-10', 'sold', 0, NULL),
	(35, 1372, 'Ltr(s)', 1, 385.72, 0.00, 0, NULL, 385.72, 23, '2015-10', 'sold', 0, NULL),
	(36, 1360, 'Ltr(s)', 1, 260.72, 0.00, 0, NULL, 260.72, 23, '2015-10', 'sold', 0, NULL),
	(37, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 24, '2015-11', 'sold', 0, NULL),
	(38, 1221, 'Pc(s)', 1, 2655.00, 0.00, 0, NULL, 2655.00, 25, '2015-12', 'sold', 0, NULL),
	(39, 617, 'Pc(s)', 1, 1414.29, 0.00, 0, NULL, 1414.29, 26, '2015-13', 'sold', 0, NULL),
	(40, 1094, 'Pc(s)', 1, 880.00, 0.00, 5, NULL, 836.00, 27, '2015-14', 'sold', 0, NULL),
	(41, 361, 'Pc(s)', 1, 2090.00, 0.00, 5, NULL, 1985.50, 28, '2015-15', 'sold', 0, NULL),
	(42, 314, 'Pc(s)', 1, 2420.00, 0.00, 5, NULL, 2299.00, 28, '2015-15', 'sold', 0, NULL),
	(45, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 29, '2015-16', 'sold', 0, NULL),
	(46, 1220, 'Pc(s)', 1, 3700.00, 0.00, 5, NULL, 3515.00, 30, '2015-17', 'sold', 0, NULL),
	(43, 796, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 29, '2015-16', 'sold', 0, NULL),
	(44, 793, 'Pc(s)', 1, 100.00, 0.00, 0, NULL, 100.00, 29, '2015-16', 'sold', 0, NULL),
	(47, 808, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 31, '2015-18', 'sold', 0, NULL),
	(48, 756, 'Pc(s)', 1, 100.00, 0.00, 0, NULL, 100.00, 31, '2015-18', 'sold', 0, NULL),
	(49, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 31, '2015-18', 'sold', 0, NULL),
	(71, 537, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 44, '0', 'sold', 0, NULL),
	(70, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 44, '0', 'sold', 0, NULL),
	(69, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 44, '0', 'sold', 0, NULL),
	(53, 730, 'Pc(s)', 1, 1650.00, 0.00, 0, NULL, 1650.00, 33, '2015-20', 'sold', 0, NULL),
	(55, 1095, 'Pc(s)', 1, 880.00, 0.00, 5, NULL, 836.00, 34, '2015-21', 'sold', 0, NULL),
	(54, 1011, 'Pc(s)', 1, 605.00, 0.00, 5, NULL, 574.75, 34, '2015-21', 'sold', 0, NULL),
	(72, 1371, 'Ltr(s)', 1, 655.00, NULL, 0, NULL, 655.00, 45, '0', 'sold', 0, NULL),
	(73, 537, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 45, '0', 'sold', 0, NULL),
	(74, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 45, '0', 'sold', 0, NULL),
	(75, 809, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 46, '2015-22', 'sold', 0, NULL),
	(76, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 46, '2015-22', 'sold', 0, NULL),
	(107, 13, 'Unit(s)', 1, 199000.00, 0.00, 0, NULL, 199000.00, 67, '0', 'sold', 12, ''),
	(78, 1235, 'Pc(s)', 1, 4150.00, 0.00, 5, NULL, 3942.50, 48, '2015-24', 'sold', 0, NULL),
	(106, 23, 'Unit(s)', 1, 620000.00, 0.00, 0, NULL, 620000.00, 66, '0', 'sold', 30, ''),
	(105, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 64, '0', 'sold', 0, NULL),
	(102, 1382, 'Set(s)', 1, 52175.00, NULL, 0, NULL, 52175.00, 63, '0', 'sold', 0, NULL),
	(101, 1182, 'Pc(s)', 1, 9735.00, 0.00, 5, NULL, 9248.25, 62, '2015-35', 'sold', 0, NULL),
	(99, 1372, 'Ltr(s)', 1, 670.00, NULL, 0, NULL, 670.00, 61, '0', 'sold', 0, NULL),
	(98, 307, 'Pc(s)', 1, 4180.00, 0.00, 5, NULL, 3971.00, 60, '2015-34', 'sold', 0, NULL),
	(97, 314, 'Pc(s)', 1, 2420.00, 0.00, 5, NULL, 2299.00, 60, '2015-34', 'sold', 0, NULL),
	(88, 1372, 'Ltr(s)', 1, 670.00, 0.00, 0, NULL, 670.00, 52, '2015-28', 'sold', 0, NULL),
	(89, 361, 'Pc(s)', 1, 2090.00, 0.00, 0, NULL, 2090.00, 53, '2015-29', 'sold', 0, NULL),
	(90, 1223, 'Pc(s)', 1, 2885.00, 0.00, 5, NULL, 2740.75, 54, '2015-30', 'sold', 0, NULL),
	(91, 1371, 'Ltr(s)', 2, 655.00, 0.00, 0, NULL, 1310.00, 55, '2015-31', 'sold', 0, NULL),
	(104, 537, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 64, '0', 'sold', 0, NULL),
	(103, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 64, '0', 'sold', 0, NULL),
	(100, 1376, 'Ltr(s)', 1, 655.00, NULL, 0, NULL, 655.00, 61, '0', 'sold', 0, NULL),
	(95, 537, 'Pc(s)', 1, 660.00, 0.00, 0, NULL, 660.00, 57, '2015-33', 'sold', 0, NULL),
	(96, 1371, 'Ltr(s)', 1, 655.00, NULL, 0, NULL, 655.00, 59, '0', 'sold', 0, NULL),
	(108, 1226, 'Pc(s)', 1, 2885.00, 0.00, 0, NULL, 2885.00, 68, '2015-36', 'sold', 0, NULL),
	(109, 810, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 68, '2015-36', 'sold', 0, NULL),
	(110, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 68, '2015-36', 'sold', 0, NULL),
	(111, 1221, 'Pc(s)', 1, 2655.00, 0.00, 0, NULL, 2655.00, 69, '2015-37', 'sold', 0, NULL),
	(112, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 70, '0', 'sold', 0, NULL),
	(113, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 70, '0', 'sold', 0, NULL),
	(114, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 71, '0', 'sold', 0, NULL),
	(115, 441, 'Pc(s)', 1, 535.71, NULL, 0, NULL, 535.71, 72, '0', 'sold', 0, NULL),
	(116, 1090, 'Pc(s)', 1, 435.00, 0.00, 0, NULL, 435.00, 74, '2015-38', 'sold', 0, NULL),
	(117, 1090, 'Pc(s)', 1, 435.00, 0.00, 10, NULL, 391.50, 75, '2015-39', 'sold', 0, NULL),
	(118, 13, 'Unit(s)', 1, 199000.00, 0.00, 0, NULL, 199000.00, 76, '0', 'sold', 13, ''),
	(119, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 77, '2015-40', 'sold', 0, NULL),
	(120, 807, 'Pc(s)', 1, 145.80, 0.00, 0, NULL, 145.80, 77, '2015-40', 'sold', 0, NULL),
	(121, 1220, 'Pc(s)', 1, 3700.00, 0.00, 0, NULL, 3700.00, 77, '2015-40', 'sold', 0, NULL),
	(122, 1371, 'Ltr(s)', 2, 377.68, NULL, 0, NULL, 755.36, 78, '0', 'sold', 0, NULL),
	(123, 537, 'Pc(s)', 1, 295.00, NULL, 0, NULL, 295.00, 78, '0', 'sold', 0, NULL),
	(124, 726, 'Pc(s)', 1, 15.00, NULL, 0, NULL, 15.00, 78, '0', 'sold', 0, NULL),
	(125, 1098, 'Pc(s)', 1, 880.00, 0.00, 0, NULL, 880.00, 80, '2015-41', 'sold', 0, NULL),
	(126, 1351, 'Ltr(s)', 3, 540.00, NULL, 0, NULL, 1620.00, 81, '0', 'sold', 0, NULL),
	(127, 1351, 'Ltr(s)', 3, 540.00, NULL, 0, NULL, 1620.00, 82, '0', 'sold', 0, NULL),
	(128, 155, 'Pc(s)', 1, 925.00, NULL, 0, NULL, 925.00, 82, '0', 'sold', 0, NULL),
	(129, 331, 'Pc(s)', 1, 4125.00, 0.00, 5, NULL, 3918.75, 83, '2015-42', 'sold', 0, NULL),
	(130, 537, 'Pc(s)', 1, 660.00, 0.00, 0, NULL, 660.00, 84, '2015-43', 'sold', 0, NULL),
	(131, 764, 'Pc(s)', 1, 555.00, NULL, 5, NULL, 527.25, 87, '0', 'sold', 0, NULL),
	(132, 1377, 'Ltr(s)', 2, 670.00, NULL, 5, NULL, 1273.00, 87, '0', 'sold', 0, NULL),
	(133, 1385, 'Pc(s)', 1, 128.53, 0.00, 0, NULL, 128.53, 88, '2015-44', 'sold', 0, NULL),
	(134, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 88, '2015-44', 'sold', 0, NULL),
	(135, 1225, 'Pc(s)', 1, 2305.00, 0.00, 0, NULL, 2305.00, 88, '2015-44', 'sold', 0, NULL),
	(136, 13, 'Unit(s)', 1, 199000.00, 0.00, 0, NULL, 199000.00, 89, '0', 'sold', 14, ''),
	(137, 1375, 'Ltr(s)', 2, 585.00, 0.00, 0, NULL, 1170.00, 91, '2015-45', 'sold', 0, NULL),
	(138, 1094, 'Pc(s)', 1, 880.00, 0.00, 0, NULL, 880.00, 92, '2015-46', 'sold', 0, NULL),
	(139, 1400, 'Pack(s)', 1, 1260.00, 0.00, 0, NULL, 1260.00, 93, '2015-47', 'sold', 0, NULL),
	(140, 1372, 'Ltr(s)', 1, 670.00, 0.00, 0, NULL, 670.00, 94, '2015-48', 'sold', 0, NULL),
	(141, 1364, 'Ltr(s)', 1, 805.00, 0.00, 0, NULL, 805.00, 94, '2015-48', 'sold', 0, NULL),
	(142, 1400, 'Pack(s)', 1, 1390.00, 0.00, 0, NULL, 1390.00, 98, '2015-49', 'sold', 0, NULL),
	(143, 17, 'Unit(s)', 1, 169000.00, 0.00, 0, NULL, 169000.00, 99, '0', 'sold', 9, ''),
	(144, 1375, 'Ltr(s)', 1, 585.00, 0.00, 5, NULL, 555.75, 100, '2015-50', 'sold', 0, NULL),
	(145, 17, 'Unit(s)', 1, 131120.00, 0.00, 0, NULL, 131120.00, 101, '0', 'sold', 8, ''),
	(146, 1364, 'Ltr(s)', 1, 805.00, 0.00, 0, NULL, 805.00, 104, '2015-51', 'sold', 0, NULL),
	(147, 1371, 'Ltr(s)', 1, 655.00, 0.00, 0, NULL, 655.00, 104, '2015-51', 'sold', 0, NULL),
	(148, 1406, 'Pc(s)', 1, 600.00, NULL, 0, NULL, 600.00, 105, '0', 'sold', 0, NULL),
	(149, 1371, 'Ltr(s)', 1, 655.00, 0.00, 0, NULL, 655.00, 106, '2015-52', 'sold', 0, NULL),
	(150, 537, 'Pc(s)', 1, 660.00, 0.00, 0, NULL, 660.00, 106, '2015-52', 'sold', 0, NULL),
	(151, 726, 'Pc(s)', 1, 55.00, 0.00, 0, NULL, 55.00, 106, '2015-52', 'sold', 0, NULL),
	(152, 14, 'Unit(s)', 1, 399000.00, 0.00, 0, NULL, 399000.00, 107, '0', 'sold', 5, ''),
	(153, 14, 'Unit(s)', 1, 399000.00, 0.00, 0, NULL, 399000.00, 108, '0', 'sold', 6, ''),
	(154, 1086, 'Pc(s)', 1, 5525.00, 0.00, 10, NULL, 4972.50, 109, '2015-53', 'sold', 0, NULL),
	(155, 1403, 'Pc(s)', 1, 5555.00, 0.00, 0, NULL, 5555.00, 109, '2015-53', 'sold', 0, NULL),
	(156, 810, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 110, '2015-54', 'sold', 0, NULL),
	(157, 807, 'Pc(s)', 1, 145.85, 0.00, 0, NULL, 145.85, 110, '2015-54', 'sold', 0, NULL),
	(158, 811, 'Pc(s)', 2, 27.00, 0.00, 0, NULL, 54.00, 110, '2015-54', 'sold', 0, NULL),
	(159, 1222, 'Pc(s)', 1, 3700.00, 0.00, 0, NULL, 3700.00, 110, '2015-54', 'sold', 0, NULL),
	(160, 1228, 'Pc(s)', 1, 2655.00, 0.00, 0, NULL, 2655.00, 110, '2015-54', 'sold', 0, NULL),
	(161, 1364, 'Ltr(s)', 1, 805.00, 0.00, 0, NULL, 805.00, 111, '2015-55', 'sold', 0, NULL),
	(162, 1375, 'Ltr(s)', 1, 585.00, 0.00, 0, NULL, 585.00, 112, '2015-56', 'sold', 0, NULL),
	(163, 725, 'Pc(s)', 1, 180.00, 0.00, 0, NULL, 180.00, 115, '2015-57', 'sold', 0, NULL),
	(164, 1364, 'Ltr(s)', 1, 805.00, 0.00, 0, NULL, 805.00, 116, '2015-58', 'sold', 0, NULL),
	(165, 1091, 'Pc(s)', 1, 435.00, 0.00, 0, NULL, 435.00, 117, '2015-59', 'sold', 0, NULL),
	(166, 1381, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 118, '0', 'sold', 0, NULL),
	(167, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 119, '2015-60', 'sold', 0, NULL),
	(168, 1414, 'Unit(s)', 1, 115000.00, 0.00, 0, NULL, 115000.00, 120, '0', 'sold', 32, 'DP - 65,000 and PDC - 1month = 50,000'),
	(169, 872, 'Pc(s)', 1, 150.00, 0.00, 0, NULL, 150.00, 121, '2015-61', 'sold', 0, NULL),
	(170, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 122, '0', 'sold', 0, NULL),
	(171, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 123, '2015-62', 'sold', 0, NULL),
	(172, 790, 'Pc(s)', 1, 128.53, 0.00, 0, NULL, 128.53, 123, '2015-62', 'sold', 0, NULL),
	(173, 1219, 'Pc(s)', 1, 2246.25, 0.00, 0, NULL, 2246.25, 123, '2015-62', 'sold', 0, NULL),
	(174, 1416, 'Unit(s)', 1, 199000.00, 0.00, 0, NULL, 199000.00, 124, '0', 'sold', 34, ''),
	(175, 1371, 'Ltr(s)', 1, 655.00, NULL, 0, NULL, 655.00, 125, '0', 'sold', 0, NULL),
	(176, 1368, 'Ltr(s)', 1, 809.00, NULL, 0, NULL, 809.00, 125, '0', 'sold', 0, NULL),
	(177, 1420, 'Pc(s)', 1, 110.00, NULL, 0, NULL, 110.00, 125, '0', 'sold', 0, NULL),
	(178, 441, 'Pc(s)', 1, 825.00, NULL, 0, NULL, 825.00, 125, '0', 'sold', 0, NULL),
	(179, 530, 'Pc(s)', 1, 1100.00, NULL, 0, NULL, 1100.00, 125, '0', 'sold', 0, NULL),
	(180, 1418, 'Pc(s)', 1, 2750.00, NULL, 0, NULL, 2750.00, 126, '0', 'sold', 0, NULL),
	(182, 799, 'Pc(s)', 1, 80.00, 0.00, 0, NULL, 80.00, 127, '2015-63', 'sold', 0, NULL),
	(181, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 127, '2015-63', 'sold', 0, NULL),
	(183, 1237, 'Pc(s)', 1, 3280.00, 0.00, 0, NULL, 3280.00, 128, '2015-64', 'sold', 0, NULL),
	(184, 1380, 'Pc(s)', 1, 2310.00, 0.00, 0, NULL, 2310.00, 128, '2015-64', 'sold', 0, NULL),
	(185, 1364, 'Ltr(s)', 1, 805.00, 0.00, 5, NULL, 764.75, 129, '2015-65', 'sold', 0, NULL),
	(186, 1090, 'Pc(s)', 1, 435.00, 0.00, 0, NULL, 435.00, 130, '2015-66', 'sold', 0, NULL),
	(187, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 131, '0', 'sold', 0, NULL),
	(188, 1430, 'Unit(s)', 1, 75000.00, 0.00, 0, NULL, 75000.00, 132, '2015-67', 'sold', 0, NULL),
	(189, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 133, '0', 'sold', 0, NULL),
	(190, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 133, '0', 'sold', 0, NULL),
	(191, 537, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 133, '0', 'sold', 0, NULL),
	(192, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 134, '0', 'sold', 0, NULL),
	(193, 329, 'Pc(s)', 1, 4125.00, 0.00, 0, NULL, 4125.00, 135, '2015-68', 'sold', 0, NULL),
	(194, 1351, 'Ltr(s)', 3, 540.00, NULL, 10, NULL, 1458.00, 136, '0', 'sold', 0, NULL),
	(195, 155, 'Pc(s)', 1, 925.00, NULL, 10, NULL, 832.50, 136, '0', 'sold', 0, NULL),
	(196, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 139, '0', 'sold', 0, NULL),
	(197, 726, 'Pc(s)', 1, 55.00, NULL, 0, NULL, 55.00, 140, '0', 'sold', 0, NULL),
	(198, 1371, 'Ltr(s)', 2, 655.00, NULL, 0, NULL, 1310.00, 140, '0', 'sold', 0, NULL),
	(199, 351, 'Pc(s)', 1, 1430.00, NULL, 0, NULL, 1430.00, 140, '0', 'sold', 0, NULL),
	(200, 1364, 'Ltr(s)', 1, 805.00, NULL, 0, NULL, 805.00, 140, '0', 'sold', 0, NULL),
	(201, 537, 'Pc(s)', 1, 660.00, NULL, 0, NULL, 660.00, 140, '0', 'sold', 0, NULL),
	(202, 1388, 'Pc(s)', 1, 125.00, NULL, 0, NULL, 125.00, 140, '0', 'sold', 0, NULL),
	(203, 1397, 'Pc(s)', 1, 250.00, NULL, 0, NULL, 250.00, 140, '0', 'sold', 0, NULL),
	(204, 415, 'Pc(s)', 1, 1430.00, NULL, 0, NULL, 1430.00, 140, '0', 'sold', 0, NULL),
	(205, 811, 'Pc(s)', 1, 27.00, 0.00, 0, NULL, 27.00, 141, '2015-69', 'sold', 0, NULL),
	(206, 1424, 'Unit(s)', 1, 169000.00, 0.00, 0, NULL, 169000.00, 142, '0', 'sold', 7, ''),
	(207, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 143, '0', 'sold', 0, NULL),
	(208, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 145, '0', 'sold', 0, NULL),
	(209, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 146, '0', 'sold', 0, NULL),
	(210, 1446, 'Ltr(s)', 2, 655.00, 0.00, 0, NULL, 1310.00, 150, '2015-70', 'sold', 0, NULL),
	(211, 537, 'Pc(s)', 1, 660.00, 0.00, 0, NULL, 660.00, 150, '2015-70', 'sold', 0, NULL),
	(212, 726, 'Pc(s)', 1, 55.00, 0.00, 0, NULL, 55.00, 150, '2015-70', 'sold', 0, NULL),
	(213, 799, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 151, '0', 'sold', 0, NULL),
	(216, 725, 'Pc(s)', 1, 180.00, 0.00, 10, NULL, 162.00, 154, '2015-72', 'sold', 0, NULL),
	(215, 1434, 'Pc(s)', 1, 128.53, 0.00, 0, NULL, 128.53, 153, '2015-71', 'sold', 0, NULL),
	(217, 314, 'Pc(s)', 1, 2420.00, NULL, 5, NULL, 2299.00, 155, '0', 'sold', 0, NULL),
	(218, 334, 'Set(s)', 1, 5040.00, NULL, 5, NULL, 4788.00, 155, '0', 'sold', 0, NULL),
	(219, 1450, 'Pc(s)', 1, 2090.00, NULL, 5, NULL, 1985.50, 155, '0', 'sold', 0, NULL),
	(220, 1381, 'Pc(s)', 1, 80.00, NULL, 0, NULL, 80.00, 156, '0', 'sold', 0, NULL),
	(221, 1364, 'Ltr(s)', 1, 805.00, 0.00, 0, NULL, 805.00, 157, '2015-73', 'sold', 0, NULL),
	(222, 1266, 'Pc(s)', 1, 1620.00, 0.00, 50, NULL, 810.00, 158, '2015-74', 'sold', 0, NULL),
	(223, 931, 'Pc(s)', 1, 5346.00, 0.00, 50, NULL, 2673.00, 158, '2015-74', 'sold', 0, NULL),
	(224, 1478, 'Pc(s)', 1, 10780.00, 0.00, 50, NULL, 5390.00, 159, '2015-75', 'sold', 0, NULL),
	(225, 1178, 'Pc(s)', 1, 10010.00, 0.00, 50, NULL, 5005.00, 159, '2015-75', 'sold', 0, NULL),
	(226, 1210, 'Pc(s)', 1, 3960.00, 0.00, 50, NULL, 1980.00, 159, '2015-75', 'sold', 0, NULL),
	(227, 1399, 'Bag(s)', 1, 1080.00, 0.00, 50, NULL, 540.00, 160, '2015-76', 'sold', 0, NULL),
	(228, 1098, 'Pc(s)', 1, 880.00, 0.00, 50, NULL, 440.00, 160, '2015-76', 'sold', 0, NULL),
	(229, 904, 'Pc(s)', 1, 1859.00, 0.00, 50, NULL, 929.50, 161, '2015-77', 'sold', 0, NULL),
	(230, 1099, 'Pc(s)', 1, 880.00, 0.00, 50, NULL, 440.00, 162, '2015-78', 'sold', 0, NULL),
	(231, 1097, 'Pc(s)', 1, 880.00, 0.00, 0, NULL, 880.00, 163, '2015-79', 'sold', 0, NULL),
	(232, 1092, 'Pc(s)', 1, 435.00, 0.00, 0, NULL, 435.00, 164, '2015-80', 'sold', 0, NULL),
	(233, 1236, 'Pc(s)', 1, 4750.00, 0.00, 25, NULL, 3562.50, 165, '2015-81', 'sold', 0, NULL),
	(234, 1375, 'Ltr(s)', 1, 585.00, NULL, 0, 0.00, 585.00, 166, '0', 'sold', 0, NULL),
	(235, 1433, 'Pc(s)', 1, 2420.00, NULL, 20, 484.00, 1936.00, 167, '0', 'sold', 0, NULL),
	(236, 854, 'Set(s)', 1, 5445.00, NULL, 20, 1089.00, 4356.00, 167, '0', 'sold', 0, NULL),
	(237, 334, 'Set(s)', 1, 5040.00, NULL, 20, 1008.00, 4032.00, 167, '0', 'sold', 0, NULL),
	(238, 1039, 'Pc(s)', 1, 2970.00, 0.00, 50, 1485.00, 1485.00, 168, '2015-82', 'sold', 0, NULL),
	(239, 291, 'Set(s)', 1, 6490.00, NULL, 20, 1298.00, 5192.00, 169, '0', 'sold', 0, NULL);
/*!40000 ALTER TABLE `tblsales` ENABLE KEYS */;


-- Dumping structure for table invndc.tblsaleschrgs
DROP TABLE IF EXISTS `tblsaleschrgs`;
CREATE TABLE IF NOT EXISTS `tblsaleschrgs` (
  `idSales` int(11) NOT NULL DEFAULT '0',
  `details` varchar(100) DEFAULT NULL,
  `amnt` double(15,2) DEFAULT NULL,
  `id` int(15) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblsaleschrgs: 0 rows
/*!40000 ALTER TABLE `tblsaleschrgs` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblsaleschrgs` ENABLE KEYS */;


-- Dumping structure for table invndc.tblsalesorder
DROP TABLE IF EXISTS `tblsalesorder`;
CREATE TABLE IF NOT EXISTS `tblsalesorder` (
  `id` int(15) NOT NULL AUTO_INCREMENT,
  `soID` varchar(25) DEFAULT NULL,
  `idCustomer` int(8) DEFAULT NULL,
  `totalDiscount` double(21,2) DEFAULT NULL,
  `amntDiscount` double(21,2) DEFAULT NULL,
  `total` double(21,2) DEFAULT NULL,
  `preparedBy` varchar(50) DEFAULT NULL,
  `dateSO` date DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL,
  `terms` varchar(50) DEFAULT NULL,
  `type` varchar(25) DEFAULT NULL,
  `payMode` varchar(30) DEFAULT NULL,
  `checkNo` varchar(25) DEFAULT NULL,
  `salesStatus` varchar(15) DEFAULT NULL,
  `qno` varchar(10) DEFAULT NULL,
  `salesInvc` int(15) DEFAULT NULL,
  `salesOR` int(15) DEFAULT NULL,
  `jeid` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=170 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblsalesorder: 148 rows
/*!40000 ALTER TABLE `tblsalesorder` DISABLE KEYS */;
INSERT INTO `tblsalesorder` (`id`, `soID`, `idCustomer`, `totalDiscount`, `amntDiscount`, `total`, `preparedBy`, `dateSO`, `remarks`, `terms`, `type`, `payMode`, `checkNo`, `salesStatus`, `qno`, `salesInvc`, `salesOR`, `jeid`) VALUES
	(43, '0', 14, 0.00, NULL, 3425.00, 'Girlie G. Tolosa', '2015-08-27', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 5, '2015-6'),
	(7, '2015-2', 85, 0.00, NULL, 880.00, 'Jennifer P. Dantes', '2015-08-03', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(42, '0', 94, 0.00, NULL, 3425.00, 'Girlie G. Tolosa', '2015-08-26', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 4, '2015-5'),
	(41, '0', 23, 0.00, NULL, 775.00, 'Girlie G. Tolosa', '2015-08-22', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 3, '2015-4'),
	(6, '2015-1', 88, 0.00, NULL, 435.00, 'Jennifer P. Dantes', '2015-08-06', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(40, '0', 87, 0.00, NULL, 4545.00, 'Girlie G. Tolosa', '2015-08-12', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 2, '2015-3'),
	(39, '0', 63, 0.00, NULL, 1180.00, 'Girlie G. Tolosa', '2015-08-05', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 1, '2015-1'),
	(37, '0', 91, 0.00, NULL, 294000.00, 'Girlie G. Tolosa', '2015-08-24', '', NULL, NULL, 'Cash (Sales)-Discounted 5K', '0', 'sold', '', 3, NULL, NULL),
	(36, '0', 90, 0.00, NULL, 105000.00, 'Girlie G. Tolosa', '2015-08-11', '', NULL, NULL, 'Financing', '0', 'sold', '', 2, NULL, NULL),
	(14, '2015-3', 97, 0.00, NULL, 2025.00, 'Girlie G. Tolosa', '2015-08-12', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(15, '2015-4', 87, 133.25, NULL, 2522.25, 'Jennifer P. Dantes', '2015-08-12', '', '', '', 'Cash (Sales)', '0', 'sold', '', 0, 0, ''),
	(38, '0', 92, 0.00, NULL, 839000.00, 'Girlie G. Tolosa', '2015-08-27', '', NULL, NULL, 'Check', '0', 'sold', '', 4, NULL, NULL),
	(35, '0', 89, 0.00, NULL, 199000.00, 'Girlie G. Tolosa', '2015-08-08', '', NULL, NULL, 'Financing', '0', 'sold', '', 1, NULL, NULL),
	(18, '2015-5', 101, 0.00, NULL, 3310.00, 'Girlie G. Tolosa', '2015-08-20', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(19, '2015-6', 83, 0.00, NULL, 80.00, 'Girlie G. Tolosa', '2015-08-24', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(20, '2015-7', 23, 0.00, NULL, 182.00, 'Girlie G. Tolosa', '2015-08-25', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(21, '2015-8', 83, 0.00, NULL, 80.00, 'Girlie G. Tolosa', '2015-08-26', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(22, '2015-9', 83, 0.00, NULL, 272.85, 'Girlie G. Tolosa', '2015-08-06', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(23, '2015-10', 83, 0.00, NULL, 1112.51, 'Girlie G. Tolosa', '2015-08-06', '', '', '', 'Repair & Maintenance', '0', 'sold', '0', 0, 0, ''),
	(24, '2015-11', 83, 0.00, NULL, 27.00, 'Jennifer P. Dantes', '2015-08-11', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(25, '2015-12', 99, 0.00, NULL, 2655.00, 'Girlie G. Tolosa', '2015-08-13', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(26, '2015-13', 83, 0.00, NULL, 1414.29, 'Girlie G. Tolosa', '2015-08-14', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(27, '2015-14', 100, 44.00, NULL, 836.00, 'Girlie G. Tolosa', '2015-08-18', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(28, '2015-15', 18, 225.50, NULL, 4284.50, 'Girlie G. Tolosa', '2015-08-22', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(29, '2015-16', 83, 0.00, NULL, 272.85, 'Girlie G. Tolosa', '2015-08-24', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(30, '2015-17', 91, 185.00, NULL, 3515.00, 'Girlie G. Tolosa', '2015-08-24', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(31, '2015-18', 83, 0.00, NULL, 272.85, 'Girlie G. Tolosa', '2015-08-26', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(33, '2015-20', 93, 0.00, NULL, 1650.00, 'Girlie G. Tolosa', '2015-08-27', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(34, '2015-21', 102, 74.25, NULL, 1410.75, 'Girlie G. Tolosa', '2015-08-29', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(44, '0', 89, 0.00, NULL, 3425.00, 'Girlie G. Tolosa', '2015-08-29', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 6, '2015-7'),
	(45, '0', 39, 0.00, NULL, 2770.00, 'Girlie G. Tolosa', '2015-09-18', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 7, '2015-8'),
	(46, '2015-22', 83, 0.00, NULL, 172.85, 'Girlie G. Tolosa', '2015-09-01', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(63, '0', 104, 0.00, NULL, 53250.00, 'Girlie G. Tolosa', '2015-09-10', 'Service Labor & Materials', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 11, '2015-12'),
	(48, '2015-24', 57, 207.50, NULL, 3942.50, 'Girlie G. Tolosa', '2015-09-05', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(62, '2015-35', 104, 486.75, NULL, 9248.25, 'Girlie G. Tolosa', '2015-09-10', '', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 0, ''),
	(60, '2015-34', 102, 330.00, NULL, 6270.00, 'Girlie G. Tolosa', '2015-09-11', '', '', '', 'Check', '0', 'sold', '0', 0, 0, ''),
	(52, '2015-28', 83, 0.00, NULL, 670.00, 'Girlie G. Tolosa', '2015-09-11', '', '', '', 'Repair & Maintenance', '0', 'sold', '0', 0, 0, ''),
	(53, '2015-29', 106, 0.00, NULL, 2090.00, 'Girlie G. Tolosa', '2015-09-12', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(54, '2015-30', 107, 144.25, NULL, 2740.75, 'Girlie G. Tolosa', '2015-09-14', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(55, '2015-31', 15, 0.00, NULL, 1310.00, 'Girlie G. Tolosa', '2015-09-14', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(61, '0', 102, 0.00, NULL, 2725.00, 'Girlie G. Tolosa', '2015-09-05', 'Service Labor & Materials', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 10, '2015-11'),
	(57, '2015-33', 40, 0.00, NULL, 660.00, 'Girlie G. Tolosa', '2015-09-18', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(58, '0', 83, 0.00, NULL, 2000.00, 'Girlie G. Tolosa', '2015-09-01', 'Service Labor & Materials', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 8, '2015-9'),
	(59, '0', 82, 0.00, NULL, 1430.00, 'Girlie G. Tolosa', '2015-09-01', 'Service Labor & Materials', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 9, '2015-10'),
	(64, '0', 105, 0.00, NULL, 3425.00, 'Girlie G. Tolosa', '2015-09-11', 'Service Labor & Materials', '', '', 'Check', '0', 'sold', '0', 0, 12, '2015-14'),
	(65, '0', 83, 0.00, NULL, 1400.00, 'Girlie G. Tolosa', '2015-09-21', 'Service Labor & Materials', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 13, '2015-15'),
	(66, '0', 98, 0.00, NULL, 620000.00, 'Girlie G. Tolosa', '2015-09-01', '', NULL, NULL, 'Financing', '0', 'sold', '', 5, NULL, NULL),
	(67, '0', 93, 0.00, NULL, 199000.00, 'Girlie G. Tolosa', '2015-09-21', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 6, NULL, NULL),
	(68, '2015-36', 83, 0.00, NULL, 3057.85, 'Girlie G. Tolosa', '2015-09-21', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(69, '2015-37', 110, 0.00, NULL, 2655.00, 'Girlie G. Tolosa', '2015-09-23', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(70, '0', 111, 0.00, NULL, 2765.00, 'Girlie G. Tolosa', '2015-09-23', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 14, '2015-16'),
	(71, '0', 112, 0.00, NULL, 1455.00, 'Girlie G. Tolosa', '2015-09-28', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 15, '2015-17'),
	(72, '0', 83, 0.00, NULL, 1935.71, 'Girlie G. Tolosa', '2015-09-26', 'Service Labor & Materials', '', '', 'Advertising', '0', 'sold', '0', 0, 16, '2015-18'),
	(73, '0', 111, 0.00, NULL, 775.00, 'Joseph V. Del Rosario Jr.', '2015-10-02', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 17, '2015-19'),
	(74, '2015-38', 120, 0.00, NULL, 435.00, 'Joseph V. Del Rosario Jr.', '2015-10-02', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 7, 17, ''),
	(75, '2015-39', 60, 43.50, NULL, 391.50, 'Joseph V. Del Rosario Jr.', '2015-10-05', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 8, 0, ''),
	(76, '0', 121, 0.00, NULL, 199000.00, 'Joseph V. Del Rosario Jr.', '2015-10-06', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 9, NULL, NULL),
	(77, '2015-40', 16, 0.00, NULL, 3872.80, 'Joseph V. Del Rosario Jr.', '2015-10-06', 'FREEBIES', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(78, '0', 16, 0.00, NULL, 2505.36, 'Joseph V. Del Rosario Jr.', '2015-10-06', 'Service Labor & Materials', '', '', 'Advertising Marketing Expense', '0', 'sold', '0', 0, 18, '2015-20'),
	(79, '0', 16, 0.00, NULL, 1400.00, 'Joseph V. Del Rosario Jr.', '2015-10-06', 'Service Labor & Materials', '', '', 'Advertising Marketing Expense', '0', 'sold', '0', 0, 19, '2015-21'),
	(80, '2015-41', 29, 0.00, NULL, 880.00, 'Joseph V. Del Rosario Jr.', '2015-10-07', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 10, 0, ''),
	(81, '0', 23, 0.00, NULL, 4545.00, 'Joseph V. Del Rosario Jr.', '2015-10-10', 'Service Labor & Materials', '', '', 'Check', '966', 'sold', '0', 0, 20, '2015-23'),
	(82, '0', 92, 0.00, NULL, 4545.00, 'Joseph V. Del Rosario Jr.', '2015-10-10', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 21, '2015-24'),
	(83, '2015-42', 105, 206.25, NULL, 3918.75, 'Joseph V. Del Rosario Jr.', '2015-10-10', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 11, 0, ''),
	(84, '2015-43', 122, 0.00, NULL, 660.00, 'Joseph V. Del Rosario Jr.', '2015-10-13', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 12, 0, ''),
	(85, '0', 23, 0.00, NULL, 1075.00, 'Girlie G. Tolosa', '2015-10-14', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 22, '2015-25'),
	(86, '0', 123, 0.00, NULL, 1400.00, 'Girlie G. Tolosa', '2015-10-14', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 23, '2015-26'),
	(87, '0', 125, 0.00, NULL, 3200.25, 'Girlie G. Tolosa', '2015-10-15', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 24, '2015-29'),
	(88, '2015-44', 83, 0.00, NULL, 2460.53, 'Joseph V. Del Rosario Jr.', '2015-10-16', '', '', '', 'Advertising', '0', 'sold', '0', 0, 0, ''),
	(89, '0', 126, 0.00, NULL, 199000.00, 'Joseph V. Del Rosario Jr.', '2015-10-16', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 13, NULL, NULL),
	(90, '0', 83, 0.00, NULL, 1400.00, 'Girlie G. Tolosa', '2015-10-16', 'Service Labor & Materials', '', '', 'Advertising Marketing Expense', '0', 'sold', '0', 0, 25, '2015-30'),
	(91, '2015-45', 127, 0.00, NULL, 1170.00, 'Girlie G. Tolosa', '2015-10-19', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 14, 0, ''),
	(92, '2015-46', 128, 0.00, NULL, 880.00, 'Girlie G. Tolosa', '2015-10-19', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 15, 0, ''),
	(93, '2015-47', 23, 0.00, NULL, 1260.00, 'Girlie G. Tolosa', '2015-10-17', '', '', '', 'Check', '0', 'sold', '0', 16, 0, ''),
	(94, '2015-48', 83, 0.00, NULL, 1475.00, 'Girlie G. Tolosa', '2015-10-17', '', '', '', 'Repair & Maintenance', '0', 'sold', '0', 0, 0, ''),
	(95, '0', 83, 0.00, NULL, 1600.00, 'Girlie G. Tolosa', '2015-10-19', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 26, '2015-32'),
	(96, '0', 83, 0.00, NULL, 1600.00, 'Girlie G. Tolosa', '2015-10-19', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 27, '2015-33'),
	(97, '0', 83, 0.00, NULL, 2000.00, 'Girlie G. Tolosa', '2015-10-19', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 28, '2015-34'),
	(98, '2015-49', 129, 0.00, NULL, 1390.00, 'Joseph V. Del Rosario Jr.', '2015-10-21', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 17, 0, ''),
	(99, '0', 132, 0.00, NULL, 169000.00, 'Joseph V. Del Rosario Jr.', '2015-10-22', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 18, NULL, NULL),
	(100, '2015-50', 126, 29.25, NULL, 555.75, 'Joseph V. Del Rosario Jr.', '2015-10-23', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 19, 0, ''),
	(101, '0', 133, 0.00, NULL, 131120.00, 'Joseph V. Del Rosario Jr.', '2015-10-24', '', NULL, NULL, 'Charge (Accounts Receivable)', '0', 'sold', '', 20, NULL, NULL),
	(102, '0', 133, 0.00, NULL, 1550.00, 'Girlie G. Tolosa', '2015-10-24', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 29, '2015-35'),
	(103, '0', 23, 0.00, NULL, 1075.00, 'Joseph V. Del Rosario Jr.', '2015-10-24', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 30, '2015-36'),
	(104, '2015-51', 105, 0.00, NULL, 1460.00, 'Girlie G. Tolosa', '2015-10-26', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 21, 0, ''),
	(105, '0', 69, 0.00, NULL, 4540.00, 'Girlie G. Tolosa', '2015-10-26', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 31, '2015-31'),
	(106, '2015-52', 30, 0.00, NULL, 1370.00, 'Joseph V. Del Rosario Jr.', '2015-10-27', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 22, 0, ''),
	(107, '0', 134, 0.00, NULL, 399000.00, 'Joseph V. Del Rosario Jr.', '2015-10-26', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 23, NULL, NULL),
	(108, '0', 134, 0.00, NULL, 399000.00, 'Joseph V. Del Rosario Jr.', '2015-10-26', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 24, NULL, NULL),
	(109, '2015-53', 134, 552.50, NULL, 10527.50, 'Girlie G. Tolosa', '2015-10-26', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 25, 0, ''),
	(110, '2015-54', 83, 0.00, NULL, 6700.70, 'Girlie G. Tolosa', '2015-10-26', '', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 0, ''),
	(111, '2015-55', 134, 0.00, NULL, 805.00, 'Girlie G. Tolosa', '2015-10-26', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(112, '2015-56', 127, 0.00, NULL, 585.00, 'Girlie G. Tolosa', '2015-10-27', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(113, '0', 83, 0.00, NULL, 1635.70, 'Joseph V. Del Rosario Jr.', '2015-10-26', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 32, '37'),
	(114, '0', 83, 0.00, NULL, 1588.56, 'Joseph V. Del Rosario Jr.', '2015-10-26', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 33, '38'),
	(115, '2015-57', 135, 0.00, NULL, 180.00, 'Girlie G. Tolosa', '2015-10-29', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(116, '2015-58', 98, 0.00, NULL, 805.00, 'Girlie G. Tolosa', '2015-10-31', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 0, ''),
	(117, '2015-59', 136, 0.00, NULL, 435.00, 'Girlie G. Tolosa', '2015-11-02', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 26, 0, ''),
	(118, '0', 137, 0.00, NULL, 1580.00, 'Girlie G. Tolosa', '2015-11-06', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 34, '39'),
	(119, '2015-60', 83, 0.00, NULL, 27.00, 'Girlie G. Tolosa', '2015-11-06', 'Freebie - Italjet 125 (Mr. Castillo) ', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 0, ''),
	(120, '0', 138, 0.00, NULL, 115000.00, 'Girlie G. Tolosa', '2015-11-06', 'DP - 65,000 and PDC - 1month = 50,000', NULL, NULL, 'Check', '0', 'sold', '', 27, NULL, NULL),
	(121, '2015-61', 139, 0.00, NULL, 150.00, 'Girlie G. Tolosa', '2015-11-10', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 28, 0, ''),
	(122, '0', 83, 0.00, NULL, 1614.22, 'Girlie G. Tolosa', '2015-11-10', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 35, '40'),
	(123, '2015-62', 83, 0.00, NULL, 2401.78, 'Girlie G. Tolosa', '2015-11-11', '', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 0, ''),
	(124, '0', 140, 0.00, NULL, 199000.00, 'Girlie G. Tolosa', '2015-11-11', '', NULL, NULL, 'Financing', '0', 'sold', '', 29, NULL, NULL),
	(125, '0', 105, 0.00, NULL, 6814.00, 'Girlie G. Tolosa', '2015-11-11', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 36, '41'),
	(126, '0', 112, 0.00, NULL, 4150.00, 'Girlie G. Tolosa', '2015-11-12', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 37, '42'),
	(127, '2015-63', 83, 0.00, NULL, 107.00, 'Girlie G. Tolosa', '2015-11-14', 'for Duke 200 - Mr. Esteban ', '', '', 'Marketing Expense', '0', 'sold', '', 0, 0, ''),
	(128, '2015-64', 60, 0.00, NULL, 5590.00, 'Girlie G. Tolosa', '2015-11-14', '', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 0, 0, ''),
	(129, '2015-65', 3, 40.25, NULL, 764.75, 'Girlie G. Tolosa', '2015-11-16', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 30, 0, ''),
	(130, '2015-66', 122, 0.00, NULL, 435.00, 'Girlie G. Tolosa', '2015-11-19', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 32, 0, ''),
	(131, '0', 141, 0.00, NULL, 1697.36, 'Girlie G. Tolosa', '2015-11-19', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 38, '43'),
	(132, '2015-67', 23, 0.00, NULL, 75000.00, 'Girlie G. Tolosa', '2015-11-19', 'with DP-15K and 3mos PDC - 60K', '', '', 'Check', '0', 'sold', '0', 33, 0, ''),
	(133, '0', 142, 0.00, NULL, 3425.00, 'Girlie G. Tolosa', '2015-11-20', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 39, '44'),
	(134, '0', 83, 0.00, NULL, 1653.02, 'Girlie G. Tolosa', '2015-11-20', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 40, '45'),
	(135, '2015-68', 134, 0.00, NULL, 4125.00, 'Girlie G. Tolosa', '2015-11-23', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 34, 0, ''),
	(136, '0', 143, 0.00, NULL, 4660.50, 'Girlie G. Tolosa', '2015-11-23', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 41, '46'),
	(137, '0', 83, 0.00, NULL, 2040.00, 'Girlie G. Tolosa', '2015-11-23', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 42, '2015-47'),
	(138, '0', 83, 0.00, NULL, 1573.02, 'Girlie G. Tolosa', '2015-11-24', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 43, '48'),
	(139, '0', 83, 0.00, NULL, 1651.07, 'Girlie G. Tolosa', '2015-11-24', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 44, '50'),
	(140, '0', 115, 0.00, NULL, 8255.00, 'Girlie G. Tolosa', '2015-11-27', 'Service Labor & Materials', '', '', 'Check', '0', 'sold', '0', 0, 45, '2015-22'),
	(141, '2015-69', 83, 0.00, NULL, 27.00, 'Girlie G. Tolosa', '2015-11-28', '', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 0, ''),
	(142, '0', 144, 0.00, NULL, 169000.00, 'Girlie G. Tolosa', '2015-11-28', '', NULL, NULL, 'Cash (Sales)', '0', 'sold', '', 35, NULL, NULL),
	(143, '0', 83, 0.00, NULL, 1480.00, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 46, '51'),
	(144, '0', 83, 0.00, NULL, 1400.00, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 47, '52'),
	(145, '0', 83, 0.00, NULL, 1480.00, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 48, '53'),
	(146, '0', 83, 0.00, NULL, 1480.00, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 49, '54'),
	(147, '0', 83, 0.00, NULL, 1400.00, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 50, '55'),
	(151, '0', 83, 0.00, NULL, 1480.00, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 52, '56'),
	(149, '0', 83, 0.00, NULL, 1531.07, 'Girlie G. Tolosa', '2015-11-28', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 51, '57'),
	(150, '2015-70', 145, 0.00, NULL, 2025.00, 'Girlie G. Tolosa', '2015-12-01', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 36, 0, ''),
	(154, '2015-72', 146, 18.00, NULL, 162.00, 'Girlie G. Tolosa', '2015-12-03', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 37, 0, ''),
	(153, '2015-71', 83, 0.00, NULL, 128.53, 'Girlie G. Tolosa', '2015-11-28', '', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 0, ''),
	(155, '0', 122, 0.00, NULL, 15222.50, 'Girlie G. Tolosa', '2015-12-09', 'Service Labor & Materials', '', '', 'Cash (Sales)', '0', 'sold', '0', 0, 53, '58'),
	(156, '0', 83, 0.00, NULL, 1653.02, 'Girlie G. Tolosa', '2015-12-11', 'Service Labor & Materials', '', '', 'Marketing Expense', '0', 'sold', '0', 0, 54, '49'),
	(157, '2015-73', 148, 0.00, NULL, 805.00, 'Girlie G. Tolosa', '2015-12-12', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 38, 0, ''),
	(158, '2015-74', 131, 3483.00, NULL, 3483.00, 'Girlie G. Tolosa', '2015-12-12', 'Year End Sales 2015', '', '', 'Cash (Sales)', '0', 'sold', '0', 39, 0, ''),
	(159, '2015-75', 149, 12375.00, NULL, 12375.00, 'Girlie G. Tolosa', '2015-12-12', 'Year End Sales 2015', '', '', 'Check', '0', 'sold', '0', 0, 0, ''),
	(160, '2015-76', 126, 980.00, NULL, 980.00, 'Girlie G. Tolosa', '2015-12-14', 'Year End Sales 2015', '', '', 'Cash (Sales)', '0', 'sold', '0', 40, 0, ''),
	(161, '2015-77', 131, 929.50, NULL, 929.50, 'Girlie G. Tolosa', '2015-12-14', 'Year End Sales 2015', '', '', 'Cash (Sales)', '0', 'sold', '0', 41, 0, ''),
	(162, '2015-78', 150, 440.00, NULL, 440.00, 'Girlie G. Tolosa', '2015-12-14', 'Year End Sales 2015', '', '', 'Cash (Sales)', '0', 'sold', '0', 42, 0, ''),
	(163, '2015-79', 151, 0.00, NULL, 880.00, 'Girlie G. Tolosa', '2015-12-14', 'Advance payment - 200.00 12/14/15 ', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 43, 0, ''),
	(164, '2015-80', 152, 0.00, NULL, 435.00, 'Girlie G. Tolosa', '2015-12-14', '', '', '', 'Charge (Accounts Receivable)', '0', 'sold', '0', 44, 0, ''),
	(165, '2015-81', 149, 1187.50, NULL, 3562.50, 'Girlie G. Tolosa', '2015-12-14', '', '', '', 'Cash (Sales)', '0', 'sold', '0', 45, 0, ''),
	(166, '0', 153, 0.00, NULL, 2360.00, 'Girlie G. Tolosa', '2015-12-16', 'Service Labor & Materials', '', 'Service', 'Cash ', '', 'sold', '0', 0, 55, '2015-59'),
	(167, '0', 154, 2581.00, NULL, 11099.00, 'Annie Rose M. Deloso', '2015-12-17', 'Service Labor & Materials', '', 'Service', 'Cash ', '', 'sold', '0', 0, 56, '2015-60'),
	(168, '2015-82', 160, 1485.00, NULL, 1485.00, 'Girlie G. Tolosa', '2015-12-17', 'Year End Sales Promo 2015', '', 'Sales', 'Cash ', '', 'sold', '0', 46, 0, ''),
	(169, '0', 153, 1298.00, NULL, 4419.00, 'Girlie G. Tolosa', '2015-12-19', 'Service Labor & Materials', '', 'Service', 'Cash ', '', 'sold', '0', 0, 57, '2015-61');
/*!40000 ALTER TABLE `tblsalesorder` ENABLE KEYS */;


-- Dumping structure for table invndc.tblsalestype
DROP TABLE IF EXISTS `tblsalestype`;
CREATE TABLE IF NOT EXISTS `tblsalestype` (
  `idType` int(2) NOT NULL DEFAULT '0',
  `salesType` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`idType`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblsalestype: 4 rows
/*!40000 ALTER TABLE `tblsalestype` DISABLE KEYS */;
INSERT INTO `tblsalestype` (`idType`, `salesType`) VALUES
	(1, 'Advertising'),
	(2, 'Repair & Maintenance'),
	(3, 'Sales'),
	(4, 'Pull-out');
/*!40000 ALTER TABLE `tblsalestype` ENABLE KEYS */;


-- Dumping structure for table invndc.tblseriespo
DROP TABLE IF EXISTS `tblseriespo`;
CREATE TABLE IF NOT EXISTS `tblseriespo` (
  `POnum` int(15) NOT NULL AUTO_INCREMENT,
  `idOrder` int(15) DEFAULT NULL,
  PRIMARY KEY (`POnum`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblseriespo: ~8 rows (approximately)
/*!40000 ALTER TABLE `tblseriespo` DISABLE KEYS */;
INSERT INTO `tblseriespo` (`POnum`, `idOrder`) VALUES
	(1, 1),
	(2, 1),
	(3, 2),
	(4, 3),
	(5, 1),
	(6, 2),
	(7, 3),
	(8, 4);
/*!40000 ALTER TABLE `tblseriespo` ENABLE KEYS */;


-- Dumping structure for table invndc.tblservicecc
DROP TABLE IF EXISTS `tblservicecc`;
CREATE TABLE IF NOT EXISTS `tblservicecc` (
  `idSrvCC` int(3) NOT NULL DEFAULT '0',
  `idBrand` int(3) DEFAULT NULL,
  `ccType` varchar(25) DEFAULT NULL,
  `flatRate` double(12,2) DEFAULT NULL,
  PRIMARY KEY (`idSrvCC`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblservicecc: 3 rows
/*!40000 ALTER TABLE `tblservicecc` DISABLE KEYS */;
INSERT INTO `tblservicecc` (`idSrvCC`, `idBrand`, `ccType`, `flatRate`) VALUES
	(1, 22, '400 CC ABOVE - D ', 1850.00),
	(2, 8, '400 CC ABOVE - ND', 1850.00),
	(3, 8, '400 CC BELOW - ND\r\n', 1250.00);
/*!40000 ALTER TABLE `tblservicecc` ENABLE KEYS */;


-- Dumping structure for table invndc.tblserviceinv
DROP TABLE IF EXISTS `tblserviceinv`;
CREATE TABLE IF NOT EXISTS `tblserviceinv` (
  `idSrvcInv` int(20) NOT NULL,
  `idSrvcItem` int(20) DEFAULT NULL,
  `qtyBeg` int(10) DEFAULT NULL,
  `qtyIn` int(10) DEFAULT NULL,
  `qtyOut` int(10) DEFAULT NULL,
  `qtyEnd` int(10) DEFAULT NULL,
  `dateUpdated` date DEFAULT NULL,
  `srp` double(15,2) DEFAULT NULL,
  `cost` double(15,2) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  `remarks` varchar(150) DEFAULT NULL,
  PRIMARY KEY (`idSrvcInv`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblserviceinv: 0 rows
/*!40000 ALTER TABLE `tblserviceinv` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblserviceinv` ENABLE KEYS */;


-- Dumping structure for table invndc.tblserviceitem
DROP TABLE IF EXISTS `tblserviceitem`;
CREATE TABLE IF NOT EXISTS `tblserviceitem` (
  `idSrvcItem` int(20) NOT NULL,
  `idCategory` int(5) DEFAULT NULL,
  `idBrand` int(5) DEFAULT NULL,
  `code` int(20) DEFAULT NULL,
  `partNo` varchar(50) DEFAULT NULL,
  `itemName` varchar(100) DEFAULT NULL,
  `details` varchar(500) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `begBal` int(5) DEFAULT NULL,
  `srp` double(12,2) DEFAULT NULL,
  `cost` double(12,2) DEFAULT NULL,
  `dateAdded` date DEFAULT NULL,
  `dateUpdated` date DEFAULT NULL,
  `remarks` varchar(100) DEFAULT NULL,
  `status` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`idSrvcItem`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblserviceitem: 0 rows
/*!40000 ALTER TABLE `tblserviceitem` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblserviceitem` ENABLE KEYS */;


-- Dumping structure for table invndc.tblserviceothers
DROP TABLE IF EXISTS `tblserviceothers`;
CREATE TABLE IF NOT EXISTS `tblserviceothers` (
  `idSrvcOther` int(10) NOT NULL,
  `operations` varchar(100) DEFAULT NULL,
  `qty` int(5) DEFAULT NULL,
  `charge` double(12,2) DEFAULT NULL,
  PRIMARY KEY (`idSrvcOther`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblserviceothers: 2 rows
/*!40000 ALTER TABLE `tblserviceothers` DISABLE KEYS */;
INSERT INTO `tblserviceothers` (`idSrvcOther`, `operations`, `qty`, `charge`) VALUES
	(1, 'Miscellaneous', 1, 150.00),
	(2, 'Vulcanizing', 1, 300.00);
/*!40000 ALTER TABLE `tblserviceothers` ENABLE KEYS */;


-- Dumping structure for table invndc.tblservices
DROP TABLE IF EXISTS `tblservices`;
CREATE TABLE IF NOT EXISTS `tblservices` (
  `idServices` int(3) NOT NULL,
  `Services` varchar(300) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblservices: 9 rows
/*!40000 ALTER TABLE `tblservices` DISABLE KEYS */;
INSERT INTO `tblservices` (`idServices`, `Services`) VALUES
	(1, 'Bike Repair'),
	(2, 'Computerized Diagnostic System'),
	(3, 'Wheel Balancing and Alignment'),
	(4, 'Tire Change'),
	(5, 'Nitrogen Tire Inflation'),
	(6, 'Logistics'),
	(7, 'Bike Recovery'),
	(8, 'Towing'),
	(9, 'Insurance Repair(Certified by Malayan)');
/*!40000 ALTER TABLE `tblservices` ENABLE KEYS */;


-- Dumping structure for table invndc.tblservicetime
DROP TABLE IF EXISTS `tblservicetime`;
CREATE TABLE IF NOT EXISTS `tblservicetime` (
  `idSrvcTime` int(5) NOT NULL DEFAULT '0',
  `idModel` int(5) DEFAULT NULL,
  `code` varchar(20) DEFAULT NULL,
  `minutes` int(5) DEFAULT NULL,
  `idSrvcType` int(3) DEFAULT NULL,
  PRIMARY KEY (`idSrvcTime`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblservicetime: 4,410 rows
/*!40000 ALTER TABLE `tblservicetime` DISABLE KEYS */;
INSERT INTO `tblservicetime` (`idSrvcTime`, `idModel`, `code`, `minutes`, `idSrvcType`) VALUES
	(1, 1, '0-999-000', 25, 1),
	(2, 1, '0-999-001', 4, 2),
	(3, 1, '0-999-002', 110, 3),
	(4, 1, '0-999-003', 0, 4),
	(5, 1, '0-999-004', 2, 5),
	(6, 1, '0-999-005', 4, 6),
	(7, 1, '0-999-006', 0, 7),
	(8, 1, '0-999-007', 0, 8),
	(9, 1, '0-999-008', 2, 9),
	(10, 1, '0-999-010', 4, 10),
	(11, 1, '0-999-011', 6, 11),
	(12, 1, '0-999-013', 3, 12),
	(13, 1, '0-999-014', 3, 13),
	(14, 1, '0-999-015', 2, 14),
	(15, 1, '0-999-016', 4, 15),
	(16, 1, '0-999-017', 0, 16),
	(17, 1, '0-999-018', 2, 17),
	(18, 1, '0-999-019', 0, 18),
	(19, 1, '0-999-020', 0, 19),
	(20, 1, '0-999-021', 2, 20),
	(21, 1, '0-999-022', 2, 21),
	(22, 1, '0-999-023', 2, 22),
	(23, 1, '0-999-024', 1, 23),
	(24, 1, '0-999-025', 1, 24),
	(25, 1, '0-999-026', 1, 25),
	(26, 1, '0-999-027', 2, 26),
	(27, 1, '0-999-028', 2, 27),
	(28, 1, '0-999-029', 2, 28),
	(29, 1, '0-999-030', 5, 29),
	(30, 1, '0-999-031', 0, 30),
	(31, 1, '0-999-032', 1, 31),
	(32, 1, '0-999-033', 4, 32),
	(33, 1, '0-999-034', 3, 33),
	(34, 1, '0-999-035', 4, 34),
	(35, 1, '0-999-036', 0, 35),
	(36, 1, '0-999-037', 5, 36),
	(37, 1, '0-999-039', 0, 37),
	(38, 1, '0-999-041', 0, 38),
	(39, 1, '0-999-042', 0, 39),
	(40, 1, '0-999-043', 0, 40),
	(41, 1, '0-999-044', 15, 41),
	(42, 1, '0-999-045', 0, 42),
	(43, 1, '0-999-046', 0, 43),
	(44, 1, '0-999-047', 0, 44),
	(45, 1, '0-999-048', 0, 45),
	(46, 1, '0-999-049', 0, 46),
	(47, 1, '0-999-050', 0, 47),
	(48, 1, '0-999-051', 0, 48),
	(49, 1, '0-999-052', 0, 49),
	(50, 1, '0-999-053', 0, 50),
	(51, 1, '0-999-054', 0, 51),
	(52, 1, '0-999-055', 0, 52),
	(53, 1, '0-999-056', 0, 53),
	(54, 1, '0-999-057', 0, 54),
	(55, 1, '0-999-058', 0, 55),
	(56, 1, '0-999-059', 0, 56),
	(57, 1, '0-999-060', 0, 57),
	(58, 1, '0-999-061', 0, 58),
	(59, 1, '0-999-062', 0, 59),
	(60, 1, '0-999-063', 0, 60),
	(61, 1, '0-999-064', 0, 61),
	(62, 1, '0-999-065', 0, 62),
	(63, 1, '0-999-066', 0, 63),
	(64, 1, '0-999-067', 0, 64),
	(65, 1, '0-999-068', 0, 65),
	(66, 1, '0-999-069', 0, 66),
	(67, 1, '0-999-070', 0, 67),
	(68, 1, '0-999-071', 0, 68),
	(69, 1, '0-999-072', 0, 69),
	(70, 1, '0-999-073', 0, 70),
	(71, 1, '0-999-074', 0, 71),
	(72, 1, '0-999-075', 0, 72),
	(73, 1, '0-999-076', 0, 73),
	(74, 1, '0-999-077', 0, 74),
	(75, 1, '0-999-078', 0, 75),
	(76, 1, '0-999-079', 0, 76),
	(77, 1, '0-999-080', 0, 77),
	(78, 1, '0-999-081', 0, 78),
	(79, 1, '0-999-082', 0, 79),
	(80, 1, '0-999-083', 0, 80),
	(81, 1, '0-999-084', 0, 81),
	(82, 1, '0-999-085', 0, 82),
	(83, 1, '0-999-086', 0, 83),
	(84, 1, '0-999-087', 0, 84),
	(85, 1, '0-999-088', 0, 85),
	(86, 1, '0-999-089', 0, 86),
	(87, 1, '0-999-090', 0, 87),
	(88, 1, '0-999-091', 0, 88),
	(89, 1, '0-999-092', 0, 89),
	(90, 1, '0-999-093', 0, 90),
	(91, 1, '0-999-094', 0, 91),
	(92, 1, '0-999-095', 0, 92),
	(93, 1, '0-999-096', 0, 93),
	(94, 1, '0-999-097', 0, 94),
	(95, 1, '0-999-098', 0, 95),
	(96, 1, '0-999-099', 0, 96),
	(97, 1, '0-999-101', 0, 97),
	(98, 1, '0-999-102', 0, 98),
	(99, 1, '0-999-103', 0, 99),
	(100, 1, '0-999-104', 0, 100),
	(101, 1, '0-999-105', 0, 101),
	(102, 1, '0-999-106', 0, 102),
	(103, 1, '0-999-107', 0, 103),
	(104, 1, '0-999-108', 0, 104),
	(105, 1, '0-999-109', 0, 105),
	(106, 1, '0-999-110', 0, 106),
	(107, 1, '0-999-111', 0, 107),
	(108, 1, '0-999-112', 0, 108),
	(109, 1, '0-999-113', 0, 109),
	(110, 1, '0-999-114', 0, 110),
	(111, 1, '0-999-115', 0, 111),
	(112, 1, '0-999-116', 0, 112),
	(113, 1, '0-999-117', 0, 113),
	(114, 1, '0-999-118', 0, 114),
	(115, 1, '0-999-119', 0, 115),
	(116, 1, '0-999-120', 0, 116),
	(117, 1, '0-999-121', 0, 117),
	(118, 1, '0-999-122', 0, 118),
	(119, 1, '0-999-123', 0, 119),
	(120, 1, '0-999-124', 0, 120),
	(121, 1, '0-999-125', 0, 121),
	(122, 1, '0-999-126', 0, 122),
	(123, 1, '0-999-127', 0, 123),
	(124, 1, '0-999-128', 0, 124),
	(125, 1, '0-999-129', 0, 125),
	(126, 1, '0-999-130', 0, 126),
	(127, 1, '0-999-131', 0, 127),
	(128, 1, '0-999-132', 0, 128),
	(129, 1, '0-999-133', 0, 129),
	(130, 1, '0-999-134', 0, 130),
	(131, 1, '0-999-135', 0, 131),
	(132, 1, '0-999-136', 0, 132),
	(133, 1, '0-999-137', 0, 133),
	(134, 1, '0-999-138', 0, 134),
	(135, 1, '0-999-139', 0, 135),
	(136, 1, '0-999-140', 0, 136),
	(137, 1, '0-999-141', 0, 137),
	(138, 1, '0-999-142', 0, 138),
	(139, 1, '0-999-144', 0, 139),
	(140, 1, '0-999-145', 0, 140),
	(141, 1, '0-999-146', 0, 141),
	(142, 1, '0-999-147', 0, 142),
	(143, 1, '0-999-148', 0, 143),
	(144, 1, '0-999-149', 0, 144),
	(145, 1, '0-999-150', 0, 145),
	(146, 1, '0-999-151', 0, 146),
	(147, 1, '0-999-152', 0, 147),
	(148, 1, '0-999-153', 0, 148),
	(149, 1, '0-999-154', 0, 149),
	(150, 1, '0-999-155', 0, 150),
	(151, 1, '0-999-156', 0, 151),
	(152, 1, '0-999-157', 0, 152),
	(153, 1, '0-999-158', 0, 153),
	(154, 1, '0-999-159', 0, 154),
	(155, 1, '0-999-160', 0, 155),
	(156, 1, '0-999-161', 0, 156),
	(157, 1, '0-999-162', 0, 157),
	(158, 1, '0-999-163', 0, 158),
	(159, 1, '0-999-164', 0, 159),
	(160, 1, '0-999-165', 0, 160),
	(161, 1, '0-999-166', 0, 161),
	(162, 1, '0-999-167', 0, 162),
	(163, 1, '0-999-168', 0, 163),
	(164, 1, '0-999-169', 0, 164),
	(165, 1, '0-999-170', 0, 165),
	(166, 1, '0-999-171', 0, 166),
	(167, 1, '0-999-172', 0, 167),
	(168, 1, '0-999-173', 0, 168),
	(169, 1, '0-999-174', 0, 169),
	(170, 1, '0-999-175', 0, 170),
	(171, 1, '0-999-176', 0, 171),
	(172, 1, '0-999-177', 0, 172),
	(173, 1, '1-999-001', 3, 173),
	(174, 1, '1-999-002', 0, 174),
	(175, 1, '1-999-003', 2, 175),
	(176, 1, '1-999-004', 10, 176),
	(177, 1, '1-999-005', 12, 177),
	(178, 1, '1-999-006', 2, 178),
	(179, 1, '1-999-007', 8, 179),
	(180, 1, '1-999-008', 3, 180),
	(181, 1, '1-999-009', 10, 181),
	(182, 1, '1-999-010', 10, 182),
	(183, 1, '1-999-011', 4, 183),
	(184, 1, '1-999-012', 5, 184),
	(185, 1, '1-999-013', 2, 185),
	(186, 1, '1-999-014', 3, 186),
	(187, 1, '1-999-015', 80, 187),
	(188, 1, '1-999-016', 70, 188),
	(189, 1, '1-999-017', 70, 189),
	(190, 1, '1-999-018', 110, 190),
	(191, 1, '1-999-019', 130, 191),
	(192, 1, '1-999-020', 0, 192),
	(193, 1, '1-999-021', 0, 193),
	(194, 1, '1-999-022', 130, 194),
	(195, 1, '1-999-023', 70, 195),
	(196, 1, '1-999-024', 0, 196),
	(197, 1, '1-999-025', 0, 197),
	(198, 1, '1-999-026', 0, 198),
	(199, 1, '1-999-027', 100, 199),
	(200, 1, '1-999-028', 90, 200),
	(201, 1, '1-999-029', 90, 201),
	(202, 1, '1-999-030', 90, 202),
	(203, 1, '1-999-031', 110, 203),
	(204, 1, '1-999-032', 100, 204),
	(205, 1, '1-999-033', 120, 205),
	(206, 1, '1-999-034', 100, 206),
	(207, 1, '1-999-035', 120, 207),
	(208, 1, '1-999-036', 120, 208),
	(209, 1, '1-999-037', 130, 209),
	(210, 1, '1-999-038', 100, 210),
	(211, 1, '1-999-039', 20, 211),
	(212, 1, '1-999-040', 30, 212),
	(213, 1, '1-999-041', 20, 213),
	(214, 1, '1-999-042', 130, 214),
	(215, 1, '1-999-043', 0, 215),
	(216, 1, '1-999-044', 80, 216),
	(217, 1, '1-999-045', 80, 217),
	(218, 1, '1-999-046', 30, 218),
	(219, 1, '1-999-047', 110, 219),
	(220, 1, '1-999-048', 30, 220),
	(221, 1, '1-999-049', 8, 221),
	(222, 1, '1-999-050', 5, 222),
	(223, 1, '1-999-051', 6, 223),
	(224, 1, '1-999-052', 2, 224),
	(225, 1, '1-999-053', 6, 225),
	(226, 1, '1-999-054', 6, 226),
	(227, 1, '1-999-055', 6, 227),
	(228, 1, '1-999-056', 7, 228),
	(229, 1, '1-999-057', 50, 229),
	(230, 1, '1-999-058', 200, 230),
	(231, 1, '1-999-059', 11, 231),
	(232, 1, '1-999-060', 4, 232),
	(233, 1, '1-999-061', 6, 233),
	(234, 1, '1-999-062', 3, 234),
	(235, 1, '1-999-063', 2, 235),
	(236, 1, '1-999-064', 0, 236),
	(237, 1, '1-999-065', 0, 237),
	(238, 1, '1-999-066', 0, 238),
	(239, 1, '1-999-077', 0, 239),
	(240, 1, '2-999-000', 3, 240),
	(241, 1, '2-999-001', 3, 241),
	(242, 1, '2-999-002', 3, 242),
	(243, 1, '2-999-003', 35, 243),
	(244, 1, '2-999-004', 3, 244),
	(245, 1, '2-999-005', 3, 245),
	(246, 1, '2-999-006', 36, 246),
	(247, 1, '2-999-007', 6, 247),
	(248, 1, '2-999-008', 10, 248),
	(249, 1, '2-999-009', 1, 249),
	(250, 1, '2-999-012', 7, 250),
	(251, 1, '2-999-013', 13, 251),
	(252, 1, '2-999-014', 5, 252),
	(253, 1, '2-999-015', 5, 253),
	(254, 1, '2-999-016', 6, 254),
	(255, 1, '2-999-017', 4, 255),
	(256, 1, '2-999-018', 5, 256),
	(257, 1, '2-999-020', 5, 257),
	(258, 1, '2-999-021', 7, 258),
	(259, 1, '2-999-022', 11, 259),
	(260, 1, '2-999-023', 20, 260),
	(261, 1, '2-999-024', 0, 261),
	(262, 1, '2-999-025', 0, 262),
	(263, 1, '2-999-026', 4, 263),
	(264, 1, '2-999-027', 1, 264),
	(265, 1, '2-999-028', 5, 265),
	(266, 1, '2-999-029', 5, 266),
	(267, 1, '2-999-030', 5, 267),
	(268, 1, '2-999-031', 10, 268),
	(269, 1, '2-999-032', 6, 269),
	(270, 1, '2-999-033', 6, 270),
	(271, 1, '2-999-034', 6, 271),
	(272, 1, '2-999-035', 3, 272),
	(273, 1, '2-999-036', 3, 273),
	(274, 1, '2-999-037', 1, 274),
	(275, 1, '2-999-038', 5, 275),
	(276, 1, '2-999-039', 3, 276),
	(277, 1, '2-999-041', 100, 277),
	(278, 1, '2-999-042', 8, 278),
	(279, 1, '2-999-043', 11, 279),
	(280, 1, '2-999-044', 2, 280),
	(281, 1, '2-999-045', 3, 281),
	(282, 1, '2-999-046', 1, 282),
	(283, 1, '2-999-047', 6, 283),
	(284, 1, '2-999-048', 0, 284),
	(285, 1, '2-999-049', 6, 285),
	(286, 1, '2-999-050', 0, 286),
	(287, 1, '2-999-051', 1, 287),
	(288, 1, '2-999-052', 3, 288),
	(289, 1, '2-999-053', 2, 289),
	(290, 1, '2-999-054', 10, 290),
	(291, 1, '2-999-055', 2, 291),
	(292, 1, '2-999-056', 10, 292),
	(293, 1, '2-999-057', 3, 293),
	(294, 1, '2-999-058', 2, 294),
	(295, 1, '2-999-059', 3, 295),
	(296, 1, '2-999-061', 3, 296),
	(297, 1, '2-999-062', 3, 297),
	(298, 1, '2-999-063', 3, 298),
	(299, 1, '2-999-065', 3, 299),
	(300, 1, '2-999-066', 0, 300),
	(301, 1, '2-999-067', 7, 301),
	(302, 1, '2-999-070', 15, 302),
	(303, 1, '2-999-071', 4, 303),
	(304, 1, '2-999-074', 1, 304),
	(305, 1, '2-999-075', 0, 305),
	(306, 1, '2-999-076', 5, 306),
	(307, 1, '2-999-077', 2, 307),
	(308, 1, '2-999-078', 0, 308),
	(309, 1, '2-999-079', 0, 309),
	(310, 1, '2-999-080', 0, 310),
	(311, 1, '2-999-081', 0, 311),
	(312, 1, '2-999-082', 0, 312),
	(313, 1, '2-999-083', 3, 313),
	(314, 1, '2-999-084', 0, 314),
	(315, 1, '2-999-085', 0, 315),
	(316, 2, '0-999-000', 10, 1),
	(317, 2, '0-999-001', 3, 2),
	(318, 2, '0-999-002', 25, 3),
	(319, 2, '0-999-003', 5, 4),
	(320, 2, '0-999-004', 3, 5),
	(321, 2, '0-999-005', 2, 6),
	(322, 2, '0-999-006', 0, 7),
	(323, 2, '0-999-007', 2, 8),
	(324, 2, '0-999-008', 0, 9),
	(325, 2, '0-999-010', 6, 10),
	(326, 2, '0-999-011', 6, 11),
	(327, 2, '0-999-013', 5, 12),
	(328, 2, '0-999-014', 0, 13),
	(329, 2, '0-999-015', 2, 14),
	(330, 2, '0-999-016', 2, 15),
	(331, 2, '0-999-017', 0, 16),
	(332, 2, '0-999-018', 2, 17),
	(333, 2, '0-999-019', 0, 18),
	(334, 2, '0-999-020', 0, 19),
	(335, 2, '0-999-021', 2, 20),
	(336, 2, '0-999-022', 2, 21),
	(337, 2, '0-999-023', 2, 22),
	(338, 2, '0-999-024', 1, 23),
	(339, 2, '0-999-025', 1, 24),
	(340, 2, '0-999-026', 1, 25),
	(341, 2, '0-999-027', 1, 26),
	(342, 2, '0-999-028', 0, 27),
	(343, 2, '0-999-029', 1, 28),
	(344, 2, '0-999-030', 8, 29),
	(345, 2, '0-999-031', 7, 30),
	(346, 2, '0-999-032', 1, 31),
	(347, 2, '0-999-033', 4, 32),
	(348, 2, '0-999-034', 3, 33),
	(349, 2, '0-999-035', 4, 34),
	(350, 2, '0-999-036', 0, 35),
	(351, 2, '0-999-037', 0, 36),
	(352, 2, '0-999-039', 0, 37),
	(353, 2, '0-999-041', 0, 38),
	(354, 2, '0-999-042', 0, 39),
	(355, 2, '0-999-043', 0, 40),
	(356, 2, '0-999-044', 15, 41),
	(357, 2, '0-999-045', 0, 42),
	(358, 2, '0-999-046', 0, 43),
	(359, 2, '0-999-047', 0, 44),
	(360, 2, '0-999-048', 0, 45),
	(361, 2, '0-999-049', 0, 46),
	(362, 2, '0-999-050', 0, 47),
	(363, 2, '0-999-051', 0, 48),
	(364, 2, '0-999-052', 0, 49),
	(365, 2, '0-999-053', 0, 50),
	(366, 2, '0-999-054', 0, 51),
	(367, 2, '0-999-055', 0, 52),
	(368, 2, '0-999-056', 0, 53),
	(369, 2, '0-999-057', 0, 54),
	(370, 2, '0-999-058', 0, 55),
	(371, 2, '0-999-059', 0, 56),
	(372, 2, '0-999-060', 0, 57),
	(373, 2, '0-999-061', 0, 58),
	(374, 2, '0-999-062', 0, 59),
	(375, 2, '0-999-063', 0, 60),
	(376, 2, '0-999-064', 0, 61),
	(377, 2, '0-999-065', 0, 62),
	(378, 2, '0-999-066', 0, 63),
	(379, 2, '0-999-067', 0, 64),
	(380, 2, '0-999-068', 0, 65),
	(381, 2, '0-999-069', 0, 66),
	(382, 2, '0-999-070', 0, 67),
	(383, 2, '0-999-071', 0, 68),
	(384, 2, '0-999-072', 0, 69),
	(385, 2, '0-999-073', 0, 70),
	(386, 2, '0-999-074', 0, 71),
	(387, 2, '0-999-075', 0, 72),
	(388, 2, '0-999-076', 0, 73),
	(389, 2, '0-999-077', 0, 74),
	(390, 2, '0-999-078', 0, 75),
	(391, 2, '0-999-079', 0, 76),
	(392, 2, '0-999-080', 0, 77),
	(393, 2, '0-999-081', 0, 78),
	(394, 2, '0-999-082', 0, 79),
	(395, 2, '0-999-083', 0, 80),
	(396, 2, '0-999-084', 0, 81),
	(397, 2, '0-999-085', 0, 82),
	(398, 2, '0-999-086', 0, 83),
	(399, 2, '0-999-087', 0, 84),
	(400, 2, '0-999-088', 0, 85),
	(401, 2, '0-999-089', 0, 86),
	(402, 2, '0-999-090', 0, 87),
	(403, 2, '0-999-091', 0, 88),
	(404, 2, '0-999-092', 0, 89),
	(405, 2, '0-999-093', 0, 90),
	(406, 2, '0-999-094', 0, 91),
	(407, 2, '0-999-095', 0, 92),
	(408, 2, '0-999-096', 0, 93),
	(409, 2, '0-999-097', 0, 94),
	(410, 2, '0-999-098', 0, 95),
	(411, 2, '0-999-099', 0, 96),
	(412, 2, '0-999-101', 0, 97),
	(413, 2, '0-999-102', 0, 98),
	(414, 2, '0-999-103', 0, 99),
	(415, 2, '0-999-104', 0, 100),
	(416, 2, '0-999-105', 0, 101),
	(417, 2, '0-999-106', 0, 102),
	(418, 2, '0-999-107', 0, 103),
	(419, 2, '0-999-108', 0, 104),
	(420, 2, '0-999-109', 0, 105),
	(421, 2, '0-999-110', 0, 106),
	(422, 2, '0-999-111', 0, 107),
	(423, 2, '0-999-112', 0, 108),
	(424, 2, '0-999-113', 0, 109),
	(425, 2, '0-999-114', 0, 110),
	(426, 2, '0-999-115', 0, 111),
	(427, 2, '0-999-116', 0, 112),
	(428, 2, '0-999-117', 0, 113),
	(429, 2, '0-999-118', 0, 114),
	(430, 2, '0-999-119', 0, 115),
	(431, 2, '0-999-120', 0, 116),
	(432, 2, '0-999-121', 0, 117),
	(433, 2, '0-999-122', 0, 118),
	(434, 2, '0-999-123', 0, 119),
	(435, 2, '0-999-124', 0, 120),
	(436, 2, '0-999-125', 0, 121),
	(437, 2, '0-999-126', 0, 122),
	(438, 2, '0-999-127', 0, 123),
	(439, 2, '0-999-128', 0, 124),
	(440, 2, '0-999-129', 0, 125),
	(441, 2, '0-999-130', 0, 126),
	(442, 2, '0-999-131', 0, 127),
	(443, 2, '0-999-132', 0, 128),
	(444, 2, '0-999-133', 0, 129),
	(445, 2, '0-999-134', 0, 130),
	(446, 2, '0-999-135', 0, 131),
	(447, 2, '0-999-136', 0, 132),
	(448, 2, '0-999-137', 0, 133),
	(449, 2, '0-999-138', 0, 134),
	(450, 2, '0-999-139', 0, 135),
	(451, 2, '0-999-140', 0, 136),
	(452, 2, '0-999-141', 0, 137),
	(453, 2, '0-999-142', 0, 138),
	(454, 2, '0-999-144', 0, 139),
	(455, 2, '0-999-145', 0, 140),
	(456, 2, '0-999-146', 0, 141),
	(457, 2, '0-999-147', 0, 142),
	(458, 2, '0-999-148', 0, 143),
	(459, 2, '0-999-149', 0, 144),
	(460, 2, '0-999-150', 0, 145),
	(461, 2, '0-999-151', 0, 146),
	(462, 2, '0-999-152', 0, 147),
	(463, 2, '0-999-153', 0, 148),
	(464, 2, '0-999-154', 0, 149),
	(465, 2, '0-999-155', 0, 150),
	(466, 2, '0-999-156', 0, 151),
	(467, 2, '0-999-157', 0, 152),
	(468, 2, '0-999-158', 0, 153),
	(469, 2, '0-999-159', 0, 154),
	(470, 2, '0-999-160', 0, 155),
	(471, 2, '0-999-161', 0, 156),
	(472, 2, '0-999-162', 0, 157),
	(473, 2, '0-999-163', 0, 158),
	(474, 2, '0-999-164', 0, 159),
	(475, 2, '0-999-165', 0, 160),
	(476, 2, '0-999-166', 0, 161),
	(477, 2, '0-999-167', 0, 162),
	(478, 2, '0-999-168', 0, 163),
	(479, 2, '0-999-169', 0, 164),
	(480, 2, '0-999-170', 0, 165),
	(481, 2, '0-999-171', 0, 166),
	(482, 2, '0-999-172', 0, 167),
	(483, 2, '0-999-173', 0, 168),
	(484, 2, '0-999-174', 0, 169),
	(485, 2, '0-999-175', 0, 170),
	(486, 2, '0-999-176', 0, 171),
	(487, 2, '0-999-177', 0, 172),
	(488, 2, '1-999-001', 7, 173),
	(489, 2, '1-999-002', 2, 174),
	(490, 2, '1-999-003', 3, 175),
	(491, 2, '1-999-004', 84, 176),
	(492, 2, '1-999-005', 88, 177),
	(493, 2, '1-999-006', 2, 178),
	(494, 2, '1-999-007', 4, 179),
	(495, 2, '1-999-008', 3, 180),
	(496, 2, '1-999-009', 7, 181),
	(497, 2, '1-999-010', 10, 182),
	(498, 2, '1-999-011', 4, 183),
	(499, 2, '1-999-012', 5, 184),
	(500, 2, '1-999-013', 2, 185),
	(501, 2, '1-999-014', 3, 186),
	(502, 2, '1-999-015', 60, 187),
	(503, 2, '1-999-016', 30, 188),
	(504, 2, '1-999-017', 20, 189),
	(505, 2, '1-999-018', 97, 190),
	(506, 2, '1-999-019', 98, 191),
	(507, 2, '1-999-020', 30, 192),
	(508, 2, '1-999-021', 25, 193),
	(509, 2, '1-999-022', 62, 194),
	(510, 2, '1-999-023', 7, 195),
	(511, 2, '1-999-024', 3, 196),
	(512, 2, '1-999-025', 3, 197),
	(513, 2, '1-999-026', 3, 198),
	(514, 2, '1-999-027', 43, 199),
	(515, 2, '1-999-028', 24, 200),
	(516, 2, '1-999-029', 22, 201),
	(517, 2, '1-999-030', 14, 202),
	(518, 2, '1-999-031', 14, 203),
	(519, 2, '1-999-032', 24, 204),
	(520, 2, '1-999-033', 42, 205),
	(521, 2, '1-999-034', 24, 206),
	(522, 2, '1-999-035', 48, 207),
	(523, 2, '1-999-036', 48, 208),
	(524, 2, '1-999-037', 62, 209),
	(525, 2, '1-999-038', 38, 210),
	(526, 2, '1-999-039', 15, 211),
	(527, 2, '1-999-040', 5, 212),
	(528, 2, '1-999-041', 4, 213),
	(529, 2, '1-999-042', 98, 214),
	(530, 2, '1-999-043', 4, 215),
	(531, 2, '1-999-044', 26, 216),
	(532, 2, '1-999-045', 32, 217),
	(533, 2, '1-999-046', 90, 218),
	(534, 2, '1-999-047', 98, 219),
	(535, 2, '1-999-048', 6, 220),
	(536, 2, '1-999-049', 7, 221),
	(537, 2, '1-999-050', 5, 222),
	(538, 2, '1-999-051', 6, 223),
	(539, 2, '1-999-052', 4, 224),
	(540, 2, '1-999-053', 6, 225),
	(541, 2, '1-999-054', 6, 226),
	(542, 2, '1-999-055', 6, 227),
	(543, 2, '1-999-056', 6, 228),
	(544, 2, '1-999-057', 26, 229),
	(545, 2, '1-999-058', 170, 230),
	(546, 2, '1-999-059', 10, 231),
	(547, 2, '1-999-060', 2, 232),
	(548, 2, '1-999-061', 5, 233),
	(549, 2, '1-999-062', 3, 234),
	(550, 2, '1-999-063', 1, 235),
	(551, 2, '1-999-064', 0, 236),
	(552, 2, '1-999-065', 0, 237),
	(553, 2, '1-999-066', 0, 238),
	(554, 2, '1-999-077', 0, 239),
	(555, 2, '2-999-000', 2, 240),
	(556, 2, '2-999-001', 2, 241),
	(557, 2, '2-999-002', 2, 242),
	(558, 2, '2-999-003', 20, 243),
	(559, 2, '2-999-004', 2, 244),
	(560, 2, '2-999-005', 2, 245),
	(561, 2, '2-999-006', 25, 246),
	(562, 2, '2-999-007', 4, 247),
	(563, 2, '2-999-008', 5, 248),
	(564, 2, '2-999-009', 5, 249),
	(565, 2, '2-999-012', 3, 250),
	(566, 2, '2-999-013', 0, 251),
	(567, 2, '2-999-014', 3, 252),
	(568, 2, '2-999-015', 4, 253),
	(569, 2, '2-999-016', 7, 254),
	(570, 2, '2-999-017', 3, 255),
	(571, 2, '2-999-018', 4, 256),
	(572, 2, '2-999-020', 7, 257),
	(573, 2, '2-999-021', 7, 258),
	(574, 2, '2-999-022', 15, 259),
	(575, 2, '2-999-023', 20, 260),
	(576, 2, '2-999-024', 28, 261),
	(577, 2, '2-999-025', 18, 262),
	(578, 2, '2-999-026', 1, 263),
	(579, 2, '2-999-027', 1, 264),
	(580, 2, '2-999-028', 5, 265),
	(581, 2, '2-999-029', 5, 266),
	(582, 2, '2-999-030', 5, 267),
	(583, 2, '2-999-031', 8, 268),
	(584, 2, '2-999-032', 6, 269),
	(585, 2, '2-999-033', 8, 270),
	(586, 2, '2-999-034', 4, 271),
	(587, 2, '2-999-035', 3, 272),
	(588, 2, '2-999-036', 4, 273),
	(589, 2, '2-999-037', 1, 274),
	(590, 2, '2-999-038', 5, 275),
	(591, 2, '2-999-039', 2, 276),
	(592, 2, '2-999-041', 100, 277),
	(593, 2, '2-999-042', 8, 278),
	(594, 2, '2-999-043', 0, 279),
	(595, 2, '2-999-044', 1, 280),
	(596, 2, '2-999-045', 2, 281),
	(597, 2, '2-999-046', 1, 282),
	(598, 2, '2-999-047', 7, 283),
	(599, 2, '2-999-048', 0, 284),
	(600, 2, '2-999-049', 6, 285),
	(601, 2, '2-999-050', 0, 286),
	(602, 2, '2-999-051', 1, 287),
	(603, 2, '2-999-052', 3, 288),
	(604, 2, '2-999-053', 0, 289),
	(605, 2, '2-999-054', 2, 290),
	(606, 2, '2-999-055', 3, 291),
	(607, 2, '2-999-056', 0, 292),
	(608, 2, '2-999-057', 0, 293),
	(609, 2, '2-999-058', 0, 294),
	(610, 2, '2-999-059', 0, 295),
	(611, 2, '2-999-061', 0, 296),
	(612, 2, '2-999-062', 0, 297),
	(613, 2, '2-999-063', 0, 298),
	(614, 2, '2-999-065', 0, 299),
	(615, 2, '2-999-066', 0, 300),
	(616, 2, '2-999-067', 7, 301),
	(617, 2, '2-999-070', 8, 302),
	(618, 2, '2-999-071', 25, 303),
	(619, 2, '2-999-074', 0, 304),
	(620, 2, '2-999-075', 1, 305),
	(621, 2, '2-999-076', 5, 306),
	(622, 2, '2-999-077', 2, 307),
	(623, 2, '2-999-078', 0, 308),
	(624, 2, '2-999-079', 0, 309),
	(625, 2, '2-999-080', 0, 310),
	(626, 2, '2-999-081', 0, 311),
	(627, 2, '2-999-082', 0, 312),
	(628, 2, '2-999-083', 3, 313),
	(629, 2, '2-999-084', 0, 314),
	(630, 2, '2-999-085', 0, 315),
	(631, 3, '0-999-000', 10, 1),
	(632, 3, '0-999-001', 3, 2),
	(633, 3, '0-999-002', 27, 3),
	(634, 3, '0-999-003', 8, 4),
	(635, 3, '0-999-004', 3, 5),
	(636, 3, '0-999-005', 2, 6),
	(637, 3, '0-999-006', 0, 7),
	(638, 3, '0-999-007', 0, 8),
	(639, 3, '0-999-008', 2, 9),
	(640, 3, '0-999-010', 3, 10),
	(641, 3, '0-999-011', 6, 11),
	(642, 3, '0-999-013', 3, 12),
	(643, 3, '0-999-014', 0, 13),
	(644, 3, '0-999-015', 2, 14),
	(645, 3, '0-999-016', 4, 15),
	(646, 3, '0-999-017', 0, 16),
	(647, 3, '0-999-018', 2, 17),
	(648, 3, '0-999-019', 0, 18),
	(649, 3, '0-999-020', 0, 19),
	(650, 3, '0-999-021', 2, 20),
	(651, 3, '0-999-022', 2, 21),
	(652, 3, '0-999-023', 2, 22),
	(653, 3, '0-999-024', 1, 23),
	(654, 3, '0-999-025', 1, 24),
	(655, 3, '0-999-026', 1, 25),
	(656, 3, '0-999-027', 2, 26),
	(657, 3, '0-999-028', 0, 27),
	(658, 3, '0-999-029', 2, 28),
	(659, 3, '0-999-030', 10, 29),
	(660, 3, '0-999-031', 20, 30),
	(661, 3, '0-999-032', 1, 31),
	(662, 3, '0-999-033', 4, 32),
	(663, 3, '0-999-034', 3, 33),
	(664, 3, '0-999-035', 4, 34),
	(665, 3, '0-999-036', 40, 35),
	(666, 3, '0-999-037', 0, 36),
	(667, 3, '0-999-039', 0, 37),
	(668, 3, '0-999-041', 0, 38),
	(669, 3, '0-999-042', 0, 39),
	(670, 3, '0-999-043', 0, 40),
	(671, 3, '0-999-044', 15, 41),
	(672, 3, '0-999-045', 3, 42),
	(673, 3, '0-999-046', 0, 43),
	(674, 3, '0-999-047', 0, 44),
	(675, 3, '0-999-048', 0, 45),
	(676, 3, '0-999-049', 0, 46),
	(677, 3, '0-999-050', 0, 47),
	(678, 3, '0-999-051', 0, 48),
	(679, 3, '0-999-052', 0, 49),
	(680, 3, '0-999-053', 0, 50),
	(681, 3, '0-999-054', 0, 51),
	(682, 3, '0-999-055', 0, 52),
	(683, 3, '0-999-056', 0, 53),
	(684, 3, '0-999-057', 0, 54),
	(685, 3, '0-999-058', 0, 55),
	(686, 3, '0-999-059', 0, 56),
	(687, 3, '0-999-060', 0, 57),
	(688, 3, '0-999-061', 0, 58),
	(689, 3, '0-999-062', 0, 59),
	(690, 3, '0-999-063', 0, 60),
	(691, 3, '0-999-064', 0, 61),
	(692, 3, '0-999-065', 0, 62),
	(693, 3, '0-999-066', 0, 63),
	(694, 3, '0-999-067', 0, 64),
	(695, 3, '0-999-068', 0, 65),
	(696, 3, '0-999-069', 0, 66),
	(697, 3, '0-999-070', 0, 67),
	(698, 3, '0-999-071', 0, 68),
	(699, 3, '0-999-072', 0, 69),
	(700, 3, '0-999-073', 0, 70),
	(701, 3, '0-999-074', 0, 71),
	(702, 3, '0-999-075', 0, 72),
	(703, 3, '0-999-076', 0, 73),
	(704, 3, '0-999-077', 0, 74),
	(705, 3, '0-999-078', 0, 75),
	(706, 3, '0-999-079', 0, 76),
	(707, 3, '0-999-080', 0, 77),
	(708, 3, '0-999-081', 0, 78),
	(709, 3, '0-999-082', 0, 79),
	(710, 3, '0-999-083', 0, 80),
	(711, 3, '0-999-084', 0, 81),
	(712, 3, '0-999-085', 0, 82),
	(713, 3, '0-999-086', 0, 83),
	(714, 3, '0-999-087', 0, 84),
	(715, 3, '0-999-088', 0, 85),
	(716, 3, '0-999-089', 0, 86),
	(717, 3, '0-999-090', 0, 87),
	(718, 3, '0-999-091', 0, 88),
	(719, 3, '0-999-092', 0, 89),
	(720, 3, '0-999-093', 0, 90),
	(721, 3, '0-999-094', 0, 91),
	(722, 3, '0-999-095', 0, 92),
	(723, 3, '0-999-096', 0, 93),
	(724, 3, '0-999-097', 0, 94),
	(725, 3, '0-999-098', 0, 95),
	(726, 3, '0-999-099', 0, 96),
	(727, 3, '0-999-101', 0, 97),
	(728, 3, '0-999-102', 0, 98),
	(729, 3, '0-999-103', 0, 99),
	(730, 3, '0-999-104', 0, 100),
	(731, 3, '0-999-105', 0, 101),
	(732, 3, '0-999-106', 0, 102),
	(733, 3, '0-999-107', 0, 103),
	(734, 3, '0-999-108', 0, 104),
	(735, 3, '0-999-109', 0, 105),
	(736, 3, '0-999-110', 0, 106),
	(737, 3, '0-999-111', 0, 107),
	(738, 3, '0-999-112', 0, 108),
	(739, 3, '0-999-113', 0, 109),
	(740, 3, '0-999-114', 0, 110),
	(741, 3, '0-999-115', 0, 111),
	(742, 3, '0-999-116', 0, 112),
	(743, 3, '0-999-117', 8, 113),
	(744, 3, '0-999-118', 3, 114),
	(745, 3, '0-999-119', 15, 115),
	(746, 3, '0-999-120', 0, 116),
	(747, 3, '0-999-121', 0, 117),
	(748, 3, '0-999-122', 0, 118),
	(749, 3, '0-999-123', 0, 119),
	(750, 3, '0-999-124', 0, 120),
	(751, 3, '0-999-125', 0, 121),
	(752, 3, '0-999-126', 0, 122),
	(753, 3, '0-999-127', 0, 123),
	(754, 3, '0-999-128', 0, 124),
	(755, 3, '0-999-129', 0, 125),
	(756, 3, '0-999-130', 0, 126),
	(757, 3, '0-999-131', 0, 127),
	(758, 3, '0-999-132', 0, 128),
	(759, 3, '0-999-133', 0, 129),
	(760, 3, '0-999-134', 0, 130),
	(761, 3, '0-999-135', 0, 131),
	(762, 3, '0-999-136', 0, 132),
	(763, 3, '0-999-137', 0, 133),
	(764, 3, '0-999-138', 0, 134),
	(765, 3, '0-999-139', 0, 135),
	(766, 3, '0-999-140', 0, 136),
	(767, 3, '0-999-141', 0, 137),
	(768, 3, '0-999-142', 0, 138),
	(769, 3, '0-999-144', 0, 139),
	(770, 3, '0-999-145', 0, 140),
	(771, 3, '0-999-146', 0, 141),
	(772, 3, '0-999-147', 0, 142),
	(773, 3, '0-999-148', 0, 143),
	(774, 3, '0-999-149', 0, 144),
	(775, 3, '0-999-150', 0, 145),
	(776, 3, '0-999-151', 0, 146),
	(777, 3, '0-999-152', 0, 147),
	(778, 3, '0-999-153', 0, 148),
	(779, 3, '0-999-154', 0, 149),
	(780, 3, '0-999-155', 0, 150),
	(781, 3, '0-999-156', 0, 151),
	(782, 3, '0-999-157', 0, 152),
	(783, 3, '0-999-158', 0, 153),
	(784, 3, '0-999-159', 0, 154),
	(785, 3, '0-999-160', 0, 155),
	(786, 3, '0-999-161', 0, 156),
	(787, 3, '0-999-162', 0, 157),
	(788, 3, '0-999-163', 0, 158),
	(789, 3, '0-999-164', 0, 159),
	(790, 3, '0-999-165', 0, 160),
	(791, 3, '0-999-166', 0, 161),
	(792, 3, '0-999-167', 0, 162),
	(793, 3, '0-999-168', 0, 163),
	(794, 3, '0-999-169', 0, 164),
	(795, 3, '0-999-170', 0, 165),
	(796, 3, '0-999-171', 0, 166),
	(797, 3, '0-999-172', 0, 167),
	(798, 3, '0-999-173', 0, 168),
	(799, 3, '0-999-174', 0, 169),
	(800, 3, '0-999-175', 0, 170),
	(801, 3, '0-999-176', 0, 171),
	(802, 3, '0-999-177', 0, 172),
	(803, 3, '1-999-001', 7, 173),
	(804, 3, '1-999-002', 2, 174),
	(805, 3, '1-999-003', 3, 175),
	(806, 3, '1-999-004', 84, 176),
	(807, 3, '1-999-005', 88, 177),
	(808, 3, '1-999-006', 2, 178),
	(809, 3, '1-999-007', 4, 179),
	(810, 3, '1-999-008', 3, 180),
	(811, 3, '1-999-009', 7, 181),
	(812, 3, '1-999-010', 6, 182),
	(813, 3, '1-999-011', 4, 183),
	(814, 3, '1-999-012', 5, 184),
	(815, 3, '1-999-013', 2, 185),
	(816, 3, '1-999-014', 3, 186),
	(817, 3, '1-999-015', 60, 187),
	(818, 3, '1-999-016', 30, 188),
	(819, 3, '1-999-017', 10, 189),
	(820, 3, '1-999-018', 97, 190),
	(821, 3, '1-999-019', 97, 191),
	(822, 3, '1-999-020', 35, 192),
	(823, 3, '1-999-021', 15, 193),
	(824, 3, '1-999-022', 55, 194),
	(825, 3, '1-999-023', 7, 195),
	(826, 3, '1-999-024', 8, 196),
	(827, 3, '1-999-025', 8, 197),
	(828, 3, '1-999-026', 8, 198),
	(829, 3, '1-999-027', 42, 199),
	(830, 3, '1-999-028', 24, 200),
	(831, 3, '1-999-029', 22, 201),
	(832, 3, '1-999-030', 12, 202),
	(833, 3, '1-999-031', 12, 203),
	(834, 3, '1-999-032', 24, 204),
	(835, 3, '1-999-033', 60, 205),
	(836, 3, '1-999-034', 42, 206),
	(837, 3, '1-999-035', 30, 207),
	(838, 3, '1-999-036', 60, 208),
	(839, 3, '1-999-037', 62, 209),
	(840, 3, '1-999-038', 30, 210),
	(841, 3, '1-999-039', 10, 211),
	(842, 3, '1-999-040', 5, 212),
	(843, 3, '1-999-041', 2, 213),
	(844, 3, '1-999-042', 96, 214),
	(845, 3, '1-999-043', 2, 215),
	(846, 3, '1-999-044', 20, 216),
	(847, 3, '1-999-045', 32, 217),
	(848, 3, '1-999-046', 88, 218),
	(849, 3, '1-999-047', 96, 219),
	(850, 3, '1-999-048', 6, 220),
	(851, 3, '1-999-049', 7, 221),
	(852, 3, '1-999-050', 5, 222),
	(853, 3, '1-999-051', 6, 223),
	(854, 3, '1-999-052', 1, 224),
	(855, 3, '1-999-053', 6, 225),
	(856, 3, '1-999-054', 6, 226),
	(857, 3, '1-999-055', 6, 227),
	(858, 3, '1-999-056', 6, 228),
	(859, 3, '1-999-057', 24, 229),
	(860, 3, '1-999-058', 168, 230),
	(861, 3, '1-999-059', 6, 231),
	(862, 3, '1-999-060', 2, 232),
	(863, 3, '1-999-061', 3, 233),
	(864, 3, '1-999-062', 1, 234),
	(865, 3, '1-999-063', 1, 235),
	(866, 3, '1-999-064', 0, 236),
	(867, 3, '1-999-065', 0, 237),
	(868, 3, '1-999-066', 0, 238),
	(869, 3, '1-999-077', 0, 239),
	(870, 3, '2-999-000', 3, 240),
	(871, 3, '2-999-001', 2, 241),
	(872, 3, '2-999-002', 2, 242),
	(873, 3, '2-999-003', 20, 243),
	(874, 3, '2-999-004', 2, 244),
	(875, 3, '2-999-005', 2, 245),
	(876, 3, '2-999-006', 26, 246),
	(877, 3, '2-999-007', 2, 247),
	(878, 3, '2-999-008', 2, 248),
	(879, 3, '2-999-009', 3, 249),
	(880, 3, '2-999-012', 3, 250),
	(881, 3, '2-999-013', 0, 251),
	(882, 3, '2-999-014', 3, 252),
	(883, 3, '2-999-015', 3, 253),
	(884, 3, '2-999-016', 5, 254),
	(885, 3, '2-999-017', 3, 255),
	(886, 3, '2-999-018', 4, 256),
	(887, 3, '2-999-020', 3, 257),
	(888, 3, '2-999-021', 5, 258),
	(889, 3, '2-999-022', 7, 259),
	(890, 3, '2-999-023', 20, 260),
	(891, 3, '2-999-024', 28, 261),
	(892, 3, '2-999-025', 18, 262),
	(893, 3, '2-999-026', 2, 263),
	(894, 3, '2-999-027', 1, 264),
	(895, 3, '2-999-028', 5, 265),
	(896, 3, '2-999-029', 5, 266),
	(897, 3, '2-999-030', 5, 267),
	(898, 3, '2-999-031', 12, 268),
	(899, 3, '2-999-032', 6, 269),
	(900, 3, '2-999-033', 8, 270),
	(901, 3, '2-999-034', 4, 271),
	(902, 3, '2-999-035', 3, 272),
	(903, 3, '2-999-036', 4, 273),
	(904, 3, '2-999-037', 1, 274),
	(905, 3, '2-999-038', 3, 275),
	(906, 3, '2-999-039', 2, 276),
	(907, 3, '2-999-041', 80, 277),
	(908, 3, '2-999-042', 5, 278),
	(909, 3, '2-999-043', 5, 279),
	(910, 3, '2-999-044', 1, 280),
	(911, 3, '2-999-045', 3, 281),
	(912, 3, '2-999-046', 1, 282),
	(913, 3, '2-999-047', 4, 283),
	(914, 3, '2-999-048', 2, 284),
	(915, 3, '2-999-049', 4, 285),
	(916, 3, '2-999-050', 0, 286),
	(917, 3, '2-999-051', 1, 287),
	(918, 3, '2-999-052', 1, 288),
	(919, 3, '2-999-053', 0, 289),
	(920, 3, '2-999-054', 0, 290),
	(921, 3, '2-999-055', 1, 291),
	(922, 3, '2-999-056', 0, 292),
	(923, 3, '2-999-057', 0, 293),
	(924, 3, '2-999-058', 0, 294),
	(925, 3, '2-999-059', 0, 295),
	(926, 3, '2-999-061', 0, 296),
	(927, 3, '2-999-062', 8, 297),
	(928, 3, '2-999-063', 0, 298),
	(929, 3, '2-999-065', 0, 299),
	(930, 3, '2-999-066', 0, 300),
	(931, 3, '2-999-067', 7, 301),
	(932, 3, '2-999-070', 24, 302),
	(933, 3, '2-999-071', 20, 303),
	(934, 3, '2-999-074', 3, 304),
	(935, 3, '2-999-075', 3, 305),
	(936, 3, '2-999-076', 8, 306),
	(937, 3, '2-999-077', 1, 307),
	(938, 3, '2-999-078', 0, 308),
	(939, 3, '2-999-079', 0, 309),
	(940, 3, '2-999-080', 0, 310),
	(941, 3, '2-999-081', 0, 311),
	(942, 3, '2-999-082', 0, 312),
	(943, 3, '2-999-083', 3, 313),
	(944, 3, '2-999-084', 0, 314),
	(945, 3, '2-999-085', 0, 315),
	(946, 4, '0-999-000', 13, 1),
	(947, 4, '0-999-001', 2, 2),
	(948, 4, '0-999-002', 27, 3),
	(949, 4, '0-999-003', 5, 4),
	(950, 4, '0-999-004', 3, 5),
	(951, 4, '0-999-005', 2, 6),
	(952, 4, '0-999-006', 0, 7),
	(953, 4, '0-999-007', 3, 8),
	(954, 4, '0-999-008', 3, 9),
	(955, 4, '0-999-010', 6, 10),
	(956, 4, '0-999-011', 8, 11),
	(957, 4, '0-999-013', 5, 12),
	(958, 4, '0-999-014', 0, 13),
	(959, 4, '0-999-015', 2, 14),
	(960, 4, '0-999-016', 2, 15),
	(961, 4, '0-999-017', 0, 16),
	(962, 4, '0-999-018', 2, 17),
	(963, 4, '0-999-019', 0, 18),
	(964, 4, '0-999-020', 0, 19),
	(965, 4, '0-999-021', 2, 20),
	(966, 4, '0-999-022', 2, 21),
	(967, 4, '0-999-023', 2, 22),
	(968, 4, '0-999-024', 1, 23),
	(969, 4, '0-999-025', 1, 24),
	(970, 4, '0-999-026', 1, 25),
	(971, 4, '0-999-027', 1, 26),
	(972, 4, '0-999-028', 0, 27),
	(973, 4, '0-999-029', 1, 28),
	(974, 4, '0-999-030', 8, 29),
	(975, 4, '0-999-031', 20, 30),
	(976, 4, '0-999-032', 1, 31),
	(977, 4, '0-999-033', 4, 32),
	(978, 4, '0-999-034', 3, 33),
	(979, 4, '0-999-035', 4, 34),
	(980, 4, '0-999-036', 0, 35),
	(981, 4, '0-999-037', 0, 36),
	(982, 4, '0-999-039', 0, 37),
	(983, 4, '0-999-041', 0, 38),
	(984, 4, '0-999-042', 0, 39),
	(985, 4, '0-999-043', 0, 40),
	(986, 4, '0-999-044', 15, 41),
	(987, 4, '0-999-045', 0, 42),
	(988, 4, '0-999-046', 0, 43),
	(989, 4, '0-999-047', 0, 44),
	(990, 4, '0-999-048', 0, 45),
	(991, 4, '0-999-049', 0, 46),
	(992, 4, '0-999-050', 0, 47),
	(993, 4, '0-999-051', 0, 48),
	(994, 4, '0-999-052', 0, 49),
	(995, 4, '0-999-053', 0, 50),
	(996, 4, '0-999-054', 0, 51),
	(997, 4, '0-999-055', 0, 52),
	(998, 4, '0-999-056', 0, 53),
	(999, 4, '0-999-057', 0, 54),
	(1000, 4, '0-999-058', 0, 55),
	(1001, 4, '0-999-059', 0, 56),
	(1002, 4, '0-999-060', 0, 57),
	(1003, 4, '0-999-061', 0, 58),
	(1004, 4, '0-999-062', 0, 59),
	(1005, 4, '0-999-063', 0, 60),
	(1006, 4, '0-999-064', 0, 61),
	(1007, 4, '0-999-065', 0, 62),
	(1008, 4, '0-999-066', 0, 63),
	(1009, 4, '0-999-067', 0, 64),
	(1010, 4, '0-999-068', 0, 65),
	(1011, 4, '0-999-069', 0, 66),
	(1012, 4, '0-999-070', 0, 67),
	(1013, 4, '0-999-071', 0, 68),
	(1014, 4, '0-999-072', 0, 69),
	(1015, 4, '0-999-073', 0, 70),
	(1016, 4, '0-999-074', 0, 71),
	(1017, 4, '0-999-075', 0, 72),
	(1018, 4, '0-999-076', 0, 73),
	(1019, 4, '0-999-077', 0, 74),
	(1020, 4, '0-999-078', 0, 75),
	(1021, 4, '0-999-079', 0, 76),
	(1022, 4, '0-999-080', 0, 77),
	(1023, 4, '0-999-081', 0, 78),
	(1024, 4, '0-999-082', 0, 79),
	(1025, 4, '0-999-083', 0, 80),
	(1026, 4, '0-999-084', 0, 81),
	(1027, 4, '0-999-085', 0, 82),
	(1028, 4, '0-999-086', 0, 83),
	(1029, 4, '0-999-087', 0, 84),
	(1030, 4, '0-999-088', 0, 85),
	(1031, 4, '0-999-089', 0, 86),
	(1032, 4, '0-999-090', 0, 87),
	(1033, 4, '0-999-091', 0, 88),
	(1034, 4, '0-999-092', 0, 89),
	(1035, 4, '0-999-093', 0, 90),
	(1036, 4, '0-999-094', 0, 91),
	(1037, 4, '0-999-095', 0, 92),
	(1038, 4, '0-999-096', 0, 93),
	(1039, 4, '0-999-097', 0, 94),
	(1040, 4, '0-999-098', 0, 95),
	(1041, 4, '0-999-099', 0, 96),
	(1042, 4, '0-999-101', 0, 97),
	(1043, 4, '0-999-102', 0, 98),
	(1044, 4, '0-999-103', 0, 99),
	(1045, 4, '0-999-104', 0, 100),
	(1046, 4, '0-999-105', 0, 101),
	(1047, 4, '0-999-106', 0, 102),
	(1048, 4, '0-999-107', 0, 103),
	(1049, 4, '0-999-108', 0, 104),
	(1050, 4, '0-999-109', 0, 105),
	(1051, 4, '0-999-110', 0, 106),
	(1052, 4, '0-999-111', 0, 107),
	(1053, 4, '0-999-112', 0, 108),
	(1054, 4, '0-999-113', 0, 109),
	(1055, 4, '0-999-114', 0, 110),
	(1056, 4, '0-999-115', 0, 111),
	(1057, 4, '0-999-116', 0, 112),
	(1058, 4, '0-999-117', 0, 113),
	(1059, 4, '0-999-118', 0, 114),
	(1060, 4, '0-999-119', 0, 115),
	(1061, 4, '0-999-120', 0, 116),
	(1062, 4, '0-999-121', 0, 117),
	(1063, 4, '0-999-122', 0, 118),
	(1064, 4, '0-999-123', 0, 119),
	(1065, 4, '0-999-124', 0, 120),
	(1066, 4, '0-999-125', 0, 121),
	(1067, 4, '0-999-126', 0, 122),
	(1068, 4, '0-999-127', 0, 123),
	(1069, 4, '0-999-128', 0, 124),
	(1070, 4, '0-999-129', 0, 125),
	(1071, 4, '0-999-130', 0, 126),
	(1072, 4, '0-999-131', 0, 127),
	(1073, 4, '0-999-132', 0, 128),
	(1074, 4, '0-999-133', 0, 129),
	(1075, 4, '0-999-134', 0, 130),
	(1076, 4, '0-999-135', 0, 131),
	(1077, 4, '0-999-136', 0, 132),
	(1078, 4, '0-999-137', 0, 133),
	(1079, 4, '0-999-138', 0, 134),
	(1080, 4, '0-999-139', 0, 135),
	(1081, 4, '0-999-140', 0, 136),
	(1082, 4, '0-999-141', 0, 137),
	(1083, 4, '0-999-142', 0, 138),
	(1084, 4, '0-999-144', 0, 139),
	(1085, 4, '0-999-145', 0, 140),
	(1086, 4, '0-999-146', 0, 141),
	(1087, 4, '0-999-147', 0, 142),
	(1088, 4, '0-999-148', 0, 143),
	(1089, 4, '0-999-149', 0, 144),
	(1090, 4, '0-999-150', 0, 145),
	(1091, 4, '0-999-151', 0, 146),
	(1092, 4, '0-999-152', 0, 147),
	(1093, 4, '0-999-153', 0, 148),
	(1094, 4, '0-999-154', 0, 149),
	(1095, 4, '0-999-155', 0, 150),
	(1096, 4, '0-999-156', 0, 151),
	(1097, 4, '0-999-157', 0, 152),
	(1098, 4, '0-999-158', 0, 153),
	(1099, 4, '0-999-159', 0, 154),
	(1100, 4, '0-999-160', 0, 155),
	(1101, 4, '0-999-161', 0, 156),
	(1102, 4, '0-999-162', 0, 157),
	(1103, 4, '0-999-163', 0, 158),
	(1104, 4, '0-999-164', 0, 159),
	(1105, 4, '0-999-165', 0, 160),
	(1106, 4, '0-999-166', 0, 161),
	(1107, 4, '0-999-167', 0, 162),
	(1108, 4, '0-999-168', 0, 163),
	(1109, 4, '0-999-169', 0, 164),
	(1110, 4, '0-999-170', 0, 165),
	(1111, 4, '0-999-171', 0, 166),
	(1112, 4, '0-999-172', 0, 167),
	(1113, 4, '0-999-173', 0, 168),
	(1114, 4, '0-999-174', 0, 169),
	(1115, 4, '0-999-175', 0, 170),
	(1116, 4, '0-999-176', 0, 171),
	(1117, 4, '0-999-177', 0, 172),
	(1118, 4, '1-999-001', 7, 173),
	(1119, 4, '1-999-002', 2, 174),
	(1120, 4, '1-999-003', 3, 175),
	(1121, 4, '1-999-004', 84, 176),
	(1122, 4, '1-999-005', 88, 177),
	(1123, 4, '1-999-006', 2, 178),
	(1124, 4, '1-999-007', 4, 179),
	(1125, 4, '1-999-008', 3, 180),
	(1126, 4, '1-999-009', 7, 181),
	(1127, 4, '1-999-010', 6, 182),
	(1128, 4, '1-999-011', 4, 183),
	(1129, 4, '1-999-012', 5, 184),
	(1130, 4, '1-999-013', 2, 185),
	(1131, 4, '1-999-014', 3, 186),
	(1132, 4, '1-999-015', 60, 187),
	(1133, 4, '1-999-016', 30, 188),
	(1134, 4, '1-999-017', 20, 189),
	(1135, 4, '1-999-018', 97, 190),
	(1136, 4, '1-999-019', 98, 191),
	(1137, 4, '1-999-020', 33, 192),
	(1138, 4, '1-999-021', 25, 193),
	(1139, 4, '1-999-022', 62, 194),
	(1140, 4, '1-999-023', 7, 195),
	(1141, 4, '1-999-024', 3, 196),
	(1142, 4, '1-999-025', 3, 197),
	(1143, 4, '1-999-026', 3, 198),
	(1144, 4, '1-999-027', 43, 199),
	(1145, 4, '1-999-028', 24, 200),
	(1146, 4, '1-999-029', 22, 201),
	(1147, 4, '1-999-030', 14, 202),
	(1148, 4, '1-999-031', 14, 203),
	(1149, 4, '1-999-032', 24, 204),
	(1150, 4, '1-999-033', 60, 205),
	(1151, 4, '1-999-034', 42, 206),
	(1152, 4, '1-999-035', 30, 207),
	(1153, 4, '1-999-036', 48, 208),
	(1154, 4, '1-999-037', 62, 209),
	(1155, 4, '1-999-038', 38, 210),
	(1156, 4, '1-999-039', 15, 211),
	(1157, 4, '1-999-040', 5, 212),
	(1158, 4, '1-999-041', 4, 213),
	(1159, 4, '1-999-042', 98, 214),
	(1160, 4, '1-999-043', 4, 215),
	(1161, 4, '1-999-044', 26, 216),
	(1162, 4, '1-999-045', 32, 217),
	(1163, 4, '1-999-046', 90, 218),
	(1164, 4, '1-999-047', 98, 219),
	(1165, 4, '1-999-048', 6, 220),
	(1166, 4, '1-999-049', 7, 221),
	(1167, 4, '1-999-050', 5, 222),
	(1168, 4, '1-999-051', 6, 223),
	(1169, 4, '1-999-052', 4, 224),
	(1170, 4, '1-999-053', 6, 225),
	(1171, 4, '1-999-054', 6, 226),
	(1172, 4, '1-999-055', 6, 227),
	(1173, 4, '1-999-056', 6, 228),
	(1174, 4, '1-999-057', 26, 229),
	(1175, 4, '1-999-058', 170, 230),
	(1176, 4, '1-999-059', 10, 231),
	(1177, 4, '1-999-060', 2, 232),
	(1178, 4, '1-999-061', 5, 233),
	(1179, 4, '1-999-062', 3, 234),
	(1180, 4, '1-999-063', 1, 235),
	(1181, 4, '1-999-064', 8, 236),
	(1182, 4, '1-999-065', 0, 237),
	(1183, 4, '1-999-066', 0, 238),
	(1184, 4, '1-999-077', 0, 239),
	(1185, 4, '2-999-000', 8, 240),
	(1186, 4, '2-999-001', 3, 241),
	(1187, 4, '2-999-002', 3, 242),
	(1188, 4, '2-999-003', 20, 243),
	(1189, 4, '2-999-004', 2, 244),
	(1190, 4, '2-999-005', 2, 245),
	(1191, 4, '2-999-006', 35, 246),
	(1192, 4, '2-999-007', 5, 247),
	(1193, 4, '2-999-008', 9, 248),
	(1194, 4, '2-999-009', 2, 249),
	(1195, 4, '2-999-012', 3, 250),
	(1196, 4, '2-999-013', 15, 251),
	(1197, 4, '2-999-014', 3, 252),
	(1198, 4, '2-999-015', 4, 253),
	(1199, 4, '2-999-016', 7, 254),
	(1200, 4, '2-999-017', 3, 255),
	(1201, 4, '2-999-018', 4, 256),
	(1202, 4, '2-999-020', 7, 257),
	(1203, 4, '2-999-021', 7, 258),
	(1204, 4, '2-999-022', 15, 259),
	(1205, 4, '2-999-023', 20, 260),
	(1206, 4, '2-999-024', 28, 261),
	(1207, 4, '2-999-025', 18, 262),
	(1208, 4, '2-999-026', 1, 263),
	(1209, 4, '2-999-027', 1, 264),
	(1210, 4, '2-999-028', 5, 265),
	(1211, 4, '2-999-029', 5, 266),
	(1212, 4, '2-999-030', 5, 267),
	(1213, 4, '2-999-031', 8, 268),
	(1214, 4, '2-999-032', 6, 269),
	(1215, 4, '2-999-033', 8, 270),
	(1216, 4, '2-999-034', 4, 271),
	(1217, 4, '2-999-035', 3, 272),
	(1218, 4, '2-999-036', 4, 273),
	(1219, 4, '2-999-037', 1, 274),
	(1220, 4, '2-999-038', 5, 275),
	(1221, 4, '2-999-039', 2, 276),
	(1222, 4, '2-999-041', 100, 277),
	(1223, 4, '2-999-042', 8, 278),
	(1224, 4, '2-999-043', 8, 279),
	(1225, 4, '2-999-044', 1, 280),
	(1226, 4, '2-999-045', 2, 281),
	(1227, 4, '2-999-046', 6, 282),
	(1228, 4, '2-999-047', 7, 283),
	(1229, 4, '2-999-048', 0, 284),
	(1230, 4, '2-999-049', 6, 285),
	(1231, 4, '2-999-050', 0, 286),
	(1232, 4, '2-999-051', 2, 287),
	(1233, 4, '2-999-052', 1, 288),
	(1234, 4, '2-999-053', 5, 289),
	(1235, 4, '2-999-054', 0, 290),
	(1236, 4, '2-999-055', 1, 291),
	(1237, 4, '2-999-056', 0, 292),
	(1238, 4, '2-999-057', 0, 293),
	(1239, 4, '2-999-058', 0, 294),
	(1240, 4, '2-999-059', 0, 295),
	(1241, 4, '2-999-061', 0, 296),
	(1242, 4, '2-999-062', 0, 297),
	(1243, 4, '2-999-063', 0, 298),
	(1244, 4, '2-999-065', 0, 299),
	(1245, 4, '2-999-066', 0, 300),
	(1246, 4, '2-999-067', 7, 301),
	(1247, 4, '2-999-070', 0, 302),
	(1248, 4, '2-999-071', 8, 303),
	(1249, 4, '2-999-074', 1, 304),
	(1250, 4, '2-999-075', 3, 305),
	(1251, 4, '2-999-076', 15, 306),
	(1252, 4, '2-999-077', 2, 307),
	(1253, 4, '2-999-078', 0, 308),
	(1254, 4, '2-999-079', 0, 309),
	(1255, 4, '2-999-080', 0, 310),
	(1256, 4, '2-999-081', 10, 311),
	(1257, 4, '2-999-082', 0, 312),
	(1258, 4, '2-999-083', 3, 313),
	(1259, 4, '2-999-084', 0, 314),
	(1260, 4, '2-999-085', 0, 315),
	(1261, 5, '0-999-000', 30, 1),
	(1262, 5, '0-999-001', 18, 2),
	(1263, 5, '0-999-002', 50, 3),
	(1264, 5, '0-999-003', 25, 4),
	(1265, 5, '0-999-004', 3, 5),
	(1266, 5, '0-999-005', 2, 6),
	(1267, 5, '0-999-006', 0, 7),
	(1268, 5, '0-999-007', 0, 8),
	(1269, 5, '0-999-008', 0, 9),
	(1270, 5, '0-999-010', 5, 10),
	(1271, 5, '0-999-011', 15, 11),
	(1272, 5, '0-999-013', 3, 12),
	(1273, 5, '0-999-014', 12, 13),
	(1274, 5, '0-999-015', 2, 14),
	(1275, 5, '0-999-016', 1, 15),
	(1276, 5, '0-999-017', 0, 16),
	(1277, 5, '0-999-018', 2, 17),
	(1278, 5, '0-999-019', 0, 18),
	(1279, 5, '0-999-020', 0, 19),
	(1280, 5, '0-999-021', 2, 20),
	(1281, 5, '0-999-022', 2, 21),
	(1282, 5, '0-999-023', 2, 22),
	(1283, 5, '0-999-024', 1, 23),
	(1284, 5, '0-999-025', 1, 24),
	(1285, 5, '0-999-026', 1, 25),
	(1286, 5, '0-999-027', 2, 26),
	(1287, 5, '0-999-028', 0, 27),
	(1288, 5, '0-999-029', 2, 28),
	(1289, 5, '0-999-030', 10, 29),
	(1290, 5, '0-999-031', 20, 30),
	(1291, 5, '0-999-032', 1, 31),
	(1292, 5, '0-999-033', 4, 32),
	(1293, 5, '0-999-034', 3, 33),
	(1294, 5, '0-999-035', 6, 34),
	(1295, 5, '0-999-036', 40, 35),
	(1296, 5, '0-999-037', 0, 36),
	(1297, 5, '0-999-039', 0, 37),
	(1298, 5, '0-999-041', 15, 38),
	(1299, 5, '0-999-042', 14, 39),
	(1300, 5, '0-999-043', 70, 40),
	(1301, 5, '0-999-044', 15, 41),
	(1302, 5, '0-999-045', 25, 42),
	(1303, 5, '0-999-046', 8, 43),
	(1304, 5, '0-999-047', 7, 44),
	(1305, 5, '0-999-048', 8, 45),
	(1306, 5, '0-999-049', 10, 46),
	(1307, 5, '0-999-050', 8, 47),
	(1308, 5, '0-999-051', 8, 48),
	(1309, 5, '0-999-052', 9, 49),
	(1310, 5, '0-999-053', 110, 50),
	(1311, 5, '0-999-054', 60, 51),
	(1312, 5, '0-999-055', 60, 52),
	(1313, 5, '0-999-056', 0, 53),
	(1314, 5, '0-999-057', 0, 54),
	(1315, 5, '0-999-058', 70, 55),
	(1316, 5, '0-999-059', 70, 56),
	(1317, 5, '0-999-060', 115, 57),
	(1318, 5, '0-999-061', 20, 58),
	(1319, 5, '0-999-062', 17, 59),
	(1320, 5, '0-999-063', 16, 60),
	(1321, 5, '0-999-064', 17, 61),
	(1322, 5, '0-999-065', 70, 62),
	(1323, 5, '0-999-066', 0, 63),
	(1324, 5, '0-999-067', 0, 64),
	(1325, 5, '0-999-068', 0, 65),
	(1326, 5, '0-999-069', 0, 66),
	(1327, 5, '0-999-070', 0, 67),
	(1328, 5, '0-999-071', 0, 68),
	(1329, 5, '0-999-072', 0, 69),
	(1330, 5, '0-999-073', 75, 70),
	(1331, 5, '0-999-074', 20, 71),
	(1332, 5, '0-999-075', 7, 72),
	(1333, 5, '0-999-076', 5, 73),
	(1334, 5, '0-999-077', 125, 74),
	(1335, 5, '0-999-078', 0, 75),
	(1336, 5, '0-999-079', 10, 76),
	(1337, 5, '0-999-080', 16, 77),
	(1338, 5, '0-999-081', 0, 78),
	(1339, 5, '0-999-082', 15, 79),
	(1340, 5, '0-999-083', 3, 80),
	(1341, 5, '0-999-084', 16, 81),
	(1342, 5, '0-999-085', 16, 82),
	(1343, 5, '0-999-086', 16, 83),
	(1344, 5, '0-999-087', 70, 84),
	(1345, 5, '0-999-088', 190, 85),
	(1346, 5, '0-999-089', 15, 86),
	(1347, 5, '0-999-090', 10, 87),
	(1348, 5, '0-999-091', 15, 88),
	(1349, 5, '0-999-092', 2, 89),
	(1350, 5, '0-999-093', 3, 90),
	(1351, 5, '0-999-094', 8, 91),
	(1352, 5, '0-999-095', 40, 92),
	(1353, 5, '0-999-096', 20, 93),
	(1354, 5, '0-999-097', 3, 94),
	(1355, 5, '0-999-098', 4, 95),
	(1356, 5, '0-999-099', 0, 96),
	(1357, 5, '0-999-101', 5, 97),
	(1358, 5, '0-999-102', 6, 98),
	(1359, 5, '0-999-103', 2, 99),
	(1360, 5, '0-999-104', 0, 100),
	(1361, 5, '0-999-105', 25, 101),
	(1362, 5, '0-999-106', 6, 102),
	(1363, 5, '0-999-107', 15, 103),
	(1364, 5, '0-999-108', 12, 104),
	(1365, 5, '0-999-109', 0, 105),
	(1366, 5, '0-999-110', 15, 106),
	(1367, 5, '0-999-111', 10, 107),
	(1368, 5, '0-999-112', 10, 108),
	(1369, 5, '0-999-113', 10, 109),
	(1370, 5, '0-999-114', 4, 110),
	(1371, 5, '0-999-115', 8, 111),
	(1372, 5, '0-999-116', 2, 112),
	(1373, 5, '0-999-117', 8, 113),
	(1374, 5, '0-999-118', 3, 114),
	(1375, 5, '0-999-119', 25, 115),
	(1376, 5, '0-999-120', 0, 116),
	(1377, 5, '0-999-121', 15, 117),
	(1378, 5, '0-999-122', 15, 118),
	(1379, 5, '0-999-123', 0, 119),
	(1380, 5, '0-999-124', 25, 120),
	(1381, 5, '0-999-125', 13, 121),
	(1382, 5, '0-999-126', 15, 122),
	(1383, 5, '0-999-127', 30, 123),
	(1384, 5, '0-999-128', 8, 124),
	(1385, 5, '0-999-129', 13, 125),
	(1386, 5, '0-999-130', 13, 126),
	(1387, 5, '0-999-131', 11, 127),
	(1388, 5, '0-999-132', 20, 128),
	(1389, 5, '0-999-133', 25, 129),
	(1390, 5, '0-999-134', 2, 130),
	(1391, 5, '0-999-135', 0, 131),
	(1392, 5, '0-999-136', 0, 132),
	(1393, 5, '0-999-137', 0, 133),
	(1394, 5, '0-999-138', 0, 134),
	(1395, 5, '0-999-139', 0, 135),
	(1396, 5, '0-999-140', 0, 136),
	(1397, 5, '0-999-141', 0, 137),
	(1398, 5, '0-999-142', 0, 138),
	(1399, 5, '0-999-144', 0, 139),
	(1400, 5, '0-999-145', 0, 140),
	(1401, 5, '0-999-146', 0, 141),
	(1402, 5, '0-999-147', 0, 142),
	(1403, 5, '0-999-148', 0, 143),
	(1404, 5, '0-999-149', 0, 144),
	(1405, 5, '0-999-150', 0, 145),
	(1406, 5, '0-999-151', 0, 146),
	(1407, 5, '0-999-152', 0, 147),
	(1408, 5, '0-999-153', 0, 148),
	(1409, 5, '0-999-154', 0, 149),
	(1410, 5, '0-999-155', 0, 150),
	(1411, 5, '0-999-156', 0, 151),
	(1412, 5, '0-999-157', 0, 152),
	(1413, 5, '0-999-158', 0, 153),
	(1414, 5, '0-999-159', 0, 154),
	(1415, 5, '0-999-160', 0, 155),
	(1416, 5, '0-999-161', 0, 156),
	(1417, 5, '0-999-162', 0, 157),
	(1418, 5, '0-999-163', 0, 158),
	(1419, 5, '0-999-164', 0, 159),
	(1420, 5, '0-999-165', 0, 160),
	(1421, 5, '0-999-166', 0, 161),
	(1422, 5, '0-999-167', 0, 162),
	(1423, 5, '0-999-168', 0, 163),
	(1424, 5, '0-999-169', 0, 164),
	(1425, 5, '0-999-170', 0, 165),
	(1426, 5, '0-999-171', 0, 166),
	(1427, 5, '0-999-172', 0, 167),
	(1428, 5, '0-999-173', 0, 168),
	(1429, 5, '0-999-174', 0, 169),
	(1430, 5, '0-999-175', 0, 170),
	(1431, 5, '0-999-176', 0, 171),
	(1432, 5, '0-999-177', 0, 172),
	(1433, 5, '1-999-001', 30, 173),
	(1434, 5, '1-999-002', 25, 174),
	(1435, 5, '1-999-003', 10, 175),
	(1436, 5, '1-999-004', 140, 176),
	(1437, 5, '1-999-005', 144, 177),
	(1438, 5, '1-999-006', 15, 178),
	(1439, 5, '1-999-007', 10, 179),
	(1440, 5, '1-999-008', 3, 180),
	(1441, 5, '1-999-009', 17, 181),
	(1442, 5, '1-999-010', 18, 182),
	(1443, 5, '1-999-011', 16, 183),
	(1444, 5, '1-999-012', 0, 184),
	(1445, 5, '1-999-013', 0, 185),
	(1446, 5, '1-999-014', 15, 186),
	(1447, 5, '1-999-015', 80, 187),
	(1448, 5, '1-999-016', 60, 188),
	(1449, 5, '1-999-017', 60, 189),
	(1450, 5, '1-999-018', 144, 190),
	(1451, 5, '1-999-019', 150, 191),
	(1452, 5, '1-999-020', 65, 192),
	(1453, 5, '1-999-021', 65, 193),
	(1454, 5, '1-999-022', 85, 194),
	(1455, 5, '1-999-023', 25, 195),
	(1456, 5, '1-999-024', 30, 196),
	(1457, 5, '1-999-025', 25, 197),
	(1458, 5, '1-999-026', 25, 198),
	(1459, 5, '1-999-027', 80, 199),
	(1460, 5, '1-999-028', 35, 200),
	(1461, 5, '1-999-029', 30, 201),
	(1462, 5, '1-999-030', 40, 202),
	(1463, 5, '1-999-031', 40, 203),
	(1464, 5, '1-999-032', 59, 204),
	(1465, 5, '1-999-033', 75, 205),
	(1466, 5, '1-999-034', 75, 206),
	(1467, 5, '1-999-035', 75, 207),
	(1468, 5, '1-999-036', 75, 208),
	(1469, 5, '1-999-037', 75, 209),
	(1470, 5, '1-999-038', 80, 210),
	(1471, 5, '1-999-039', 25, 211),
	(1472, 5, '1-999-040', 15, 212),
	(1473, 5, '1-999-041', 3, 213),
	(1474, 5, '1-999-042', 150, 214),
	(1475, 5, '1-999-043', 30, 215),
	(1476, 5, '1-999-044', 60, 216),
	(1477, 5, '1-999-045', 60, 217),
	(1478, 5, '1-999-046', 150, 218),
	(1479, 5, '1-999-047', 150, 219),
	(1480, 5, '1-999-048', 17, 220),
	(1481, 5, '1-999-049', 20, 221),
	(1482, 5, '1-999-050', 2, 222),
	(1483, 5, '1-999-051', 30, 223),
	(1484, 5, '1-999-052', 3, 224),
	(1485, 5, '1-999-053', 30, 225),
	(1486, 5, '1-999-054', 30, 226),
	(1487, 5, '1-999-055', 30, 227),
	(1488, 5, '1-999-056', 30, 228),
	(1489, 5, '1-999-057', 80, 229),
	(1490, 5, '1-999-058', 200, 230),
	(1491, 5, '1-999-059', 20, 231),
	(1492, 5, '1-999-060', 12, 232),
	(1493, 5, '1-999-061', 15, 233),
	(1494, 5, '1-999-062', 1, 234),
	(1495, 5, '1-999-063', 3, 235),
	(1496, 5, '1-999-064', 0, 236),
	(1497, 5, '1-999-065', 0, 237),
	(1498, 5, '1-999-066', 0, 238),
	(1499, 5, '1-999-077', 4, 239),
	(1500, 5, '2-999-000', 0, 240),
	(1501, 5, '2-999-001', 0, 241),
	(1502, 5, '2-999-002', 0, 242),
	(1503, 5, '2-999-003', 40, 243),
	(1504, 5, '2-999-004', 30, 244),
	(1505, 5, '2-999-005', 5, 245),
	(1506, 5, '2-999-006', 45, 246),
	(1507, 5, '2-999-007', 35, 247),
	(1508, 5, '2-999-008', 3, 248),
	(1509, 5, '2-999-009', 4, 249),
	(1510, 5, '2-999-012', 2, 250),
	(1511, 5, '2-999-013', 0, 251),
	(1512, 5, '2-999-014', 3, 252),
	(1513, 5, '2-999-015', 5, 253),
	(1514, 5, '2-999-016', 5, 254),
	(1515, 5, '2-999-017', 3, 255),
	(1516, 5, '2-999-018', 4, 256),
	(1517, 5, '2-999-020', 25, 257),
	(1518, 5, '2-999-021', 10, 258),
	(1519, 5, '2-999-022', 15, 259),
	(1520, 5, '2-999-023', 17, 260),
	(1521, 5, '2-999-024', 30, 261),
	(1522, 5, '2-999-025', 20, 262),
	(1523, 5, '2-999-026', 2, 263),
	(1524, 5, '2-999-027', 10, 264),
	(1525, 5, '2-999-028', 10, 265),
	(1526, 5, '2-999-029', 8, 266),
	(1527, 5, '2-999-030', 5, 267),
	(1528, 5, '2-999-031', 10, 268),
	(1529, 5, '2-999-032', 6, 269),
	(1530, 5, '2-999-033', 6, 270),
	(1531, 5, '2-999-034', 10, 271),
	(1532, 5, '2-999-035', 5, 272),
	(1533, 5, '2-999-036', 6, 273),
	(1534, 5, '2-999-037', 1, 274),
	(1535, 5, '2-999-038', 4, 275),
	(1536, 5, '2-999-039', 3, 276),
	(1537, 5, '2-999-041', 180, 277),
	(1538, 5, '2-999-042', 20, 278),
	(1539, 5, '2-999-043', 14, 279),
	(1540, 5, '2-999-044', 1, 280),
	(1541, 5, '2-999-045', 2, 281),
	(1542, 5, '2-999-046', 1, 282),
	(1543, 5, '2-999-047', 15, 283),
	(1544, 5, '2-999-048', 10, 284),
	(1545, 5, '2-999-049', 15, 285),
	(1546, 5, '2-999-050', 3, 286),
	(1547, 5, '2-999-051', 3, 287),
	(1548, 5, '2-999-052', 0, 288),
	(1549, 5, '2-999-053', 5, 289),
	(1550, 5, '2-999-054', 5, 290),
	(1551, 5, '2-999-055', 1, 291),
	(1552, 5, '2-999-056', 25, 292),
	(1553, 5, '2-999-057', 26, 293),
	(1554, 5, '2-999-058', 6, 294),
	(1555, 5, '2-999-059', 25, 295),
	(1556, 5, '2-999-061', 30, 296),
	(1557, 5, '2-999-062', 1, 297),
	(1558, 5, '2-999-063', 26, 298),
	(1559, 5, '2-999-065', 10, 299),
	(1560, 5, '2-999-066', 10, 300),
	(1561, 5, '2-999-067', 5, 301),
	(1562, 5, '2-999-070', 35, 302),
	(1563, 5, '2-999-071', 30, 303),
	(1564, 5, '2-999-074', 0, 304),
	(1565, 5, '2-999-075', 0, 305),
	(1566, 5, '2-999-076', 0, 306),
	(1567, 5, '2-999-077', 4, 307),
	(1568, 5, '2-999-078', 0, 308),
	(1569, 5, '2-999-079', 0, 309),
	(1570, 5, '2-999-080', 0, 310),
	(1571, 5, '2-999-081', 0, 311),
	(1572, 5, '2-999-082', 0, 312),
	(1573, 5, '2-999-083', 3, 313),
	(1574, 5, '2-999-084', 0, 314),
	(1575, 5, '2-999-085', 0, 315),
	(1576, 6, '0-999-000', 20, 1),
	(1577, 6, '0-999-001', 12, 2),
	(1578, 6, '0-999-002', 50, 3),
	(1579, 6, '0-999-003', 19, 4),
	(1580, 6, '0-999-004', 3, 5),
	(1581, 6, '0-999-005', 2, 6),
	(1582, 6, '0-999-006', 0, 7),
	(1583, 6, '0-999-007', 0, 8),
	(1584, 6, '0-999-008', 3, 9),
	(1585, 6, '0-999-010', 5, 10),
	(1586, 6, '0-999-011', 15, 11),
	(1587, 6, '0-999-013', 0, 12),
	(1588, 6, '0-999-014', 10, 13),
	(1589, 6, '0-999-015', 2, 14),
	(1590, 6, '0-999-016', 1, 15),
	(1591, 6, '0-999-017', 0, 16),
	(1592, 6, '0-999-018', 2, 17),
	(1593, 6, '0-999-019', 0, 18),
	(1594, 6, '0-999-020', 0, 19),
	(1595, 6, '0-999-021', 2, 20),
	(1596, 6, '0-999-022', 2, 21),
	(1597, 6, '0-999-023', 2, 22),
	(1598, 6, '0-999-024', 1, 23),
	(1599, 6, '0-999-025', 1, 24),
	(1600, 6, '0-999-026', 1, 25),
	(1601, 6, '0-999-027', 1, 26),
	(1602, 6, '0-999-028', 0, 27),
	(1603, 6, '0-999-029', 2, 28),
	(1604, 6, '0-999-030', 10, 29),
	(1605, 6, '0-999-031', 20, 30),
	(1606, 6, '0-999-032', 1, 31),
	(1607, 6, '0-999-033', 4, 32),
	(1608, 6, '0-999-034', 3, 33),
	(1609, 6, '0-999-035', 4, 34),
	(1610, 6, '0-999-036', 50, 35),
	(1611, 6, '0-999-037', 3, 36),
	(1612, 6, '0-999-039', 0, 37),
	(1613, 6, '0-999-041', 15, 38),
	(1614, 6, '0-999-042', 14, 39),
	(1615, 6, '0-999-043', 65, 40),
	(1616, 6, '0-999-044', 15, 41),
	(1617, 6, '0-999-045', 3, 42),
	(1618, 6, '0-999-046', 8, 43),
	(1619, 6, '0-999-047', 7, 44),
	(1620, 6, '0-999-048', 8, 45),
	(1621, 6, '0-999-049', 10, 46),
	(1622, 6, '0-999-050', 8, 47),
	(1623, 6, '0-999-051', 8, 48),
	(1624, 6, '0-999-052', 9, 49),
	(1625, 6, '0-999-053', 140, 50),
	(1626, 6, '0-999-054', 100, 51),
	(1627, 6, '0-999-055', 60, 52),
	(1628, 6, '0-999-056', 130, 53),
	(1629, 6, '0-999-057', 135, 54),
	(1630, 6, '0-999-058', 110, 55),
	(1631, 6, '0-999-059', 70, 56),
	(1632, 6, '0-999-060', 135, 57),
	(1633, 6, '0-999-061', 20, 58),
	(1634, 6, '0-999-062', 17, 59),
	(1635, 6, '0-999-063', 16, 60),
	(1636, 6, '0-999-064', 17, 61),
	(1637, 6, '0-999-065', 100, 62),
	(1638, 6, '0-999-066', 30, 63),
	(1639, 6, '0-999-067', 15, 64),
	(1640, 6, '0-999-068', 80, 65),
	(1641, 6, '0-999-069', 80, 66),
	(1642, 6, '0-999-070', 50, 67),
	(1643, 6, '0-999-071', 130, 68),
	(1644, 6, '0-999-072', 110, 69),
	(1645, 6, '0-999-073', 75, 70),
	(1646, 6, '0-999-074', 20, 71),
	(1647, 6, '0-999-075', 7, 72),
	(1648, 6, '0-999-076', 3, 73),
	(1649, 6, '0-999-077', 135, 74),
	(1650, 6, '0-999-078', 15, 75),
	(1651, 6, '0-999-079', 10, 76),
	(1652, 6, '0-999-080', 16, 77),
	(1653, 6, '0-999-081', 20, 78),
	(1654, 6, '0-999-082', 15, 79),
	(1655, 6, '0-999-083', 3, 80),
	(1656, 6, '0-999-084', 16, 81),
	(1657, 6, '0-999-085', 16, 82),
	(1658, 6, '0-999-086', 16, 83),
	(1659, 6, '0-999-087', 70, 84),
	(1660, 6, '0-999-088', 190, 85),
	(1661, 6, '0-999-089', 15, 86),
	(1662, 6, '0-999-090', 8, 87),
	(1663, 6, '0-999-091', 15, 88),
	(1664, 6, '0-999-092', 5, 89),
	(1665, 6, '0-999-093', 3, 90),
	(1666, 6, '0-999-094', 10, 91),
	(1667, 6, '0-999-095', 30, 92),
	(1668, 6, '0-999-096', 12, 93),
	(1669, 6, '0-999-097', 10, 94),
	(1670, 6, '0-999-098', 10, 95),
	(1671, 6, '0-999-099', 20, 96),
	(1672, 6, '0-999-101', 5, 97),
	(1673, 6, '0-999-102', 6, 98),
	(1674, 6, '0-999-103', 2, 99),
	(1675, 6, '0-999-104', 5, 100),
	(1676, 6, '0-999-105', 25, 101),
	(1677, 6, '0-999-106', 17, 102),
	(1678, 6, '0-999-107', 25, 103),
	(1679, 6, '0-999-108', 25, 104),
	(1680, 6, '0-999-109', 20, 105),
	(1681, 6, '0-999-110', 10, 106),
	(1682, 6, '0-999-111', 10, 107),
	(1683, 6, '0-999-112', 10, 108),
	(1684, 6, '0-999-113', 10, 109),
	(1685, 6, '0-999-114', 4, 110),
	(1686, 6, '0-999-115', 8, 111),
	(1687, 6, '0-999-116', 2, 112),
	(1688, 6, '0-999-117', 8, 113),
	(1689, 6, '0-999-118', 3, 114),
	(1690, 6, '0-999-119', 25, 115),
	(1691, 6, '0-999-120', 1, 116),
	(1692, 6, '0-999-121', 15, 117),
	(1693, 6, '0-999-122', 15, 118),
	(1694, 6, '0-999-123', 15, 119),
	(1695, 6, '0-999-124', 12, 120),
	(1696, 6, '0-999-125', 11, 121),
	(1697, 6, '0-999-126', 15, 122),
	(1698, 6, '0-999-127', 10, 123),
	(1699, 6, '0-999-128', 11, 124),
	(1700, 6, '0-999-129', 11, 125),
	(1701, 6, '0-999-130', 11, 126),
	(1702, 6, '0-999-131', 11, 127),
	(1703, 6, '0-999-132', 35, 128),
	(1704, 6, '0-999-133', 25, 129),
	(1705, 6, '0-999-134', 6, 130),
	(1706, 6, '0-999-135', 3, 131),
	(1707, 6, '0-999-136', 10, 132),
	(1708, 6, '0-999-137', 3, 133),
	(1709, 6, '0-999-138', 3, 134),
	(1710, 6, '0-999-139', 60, 135),
	(1711, 6, '0-999-140', 15, 136),
	(1712, 6, '0-999-141', 2, 137),
	(1713, 6, '0-999-142', 5, 138),
	(1714, 6, '0-999-144', 3, 139),
	(1715, 6, '0-999-145', 25, 140),
	(1716, 6, '0-999-146', 25, 141),
	(1717, 6, '0-999-147', 3, 142),
	(1718, 6, '0-999-148', 15, 143),
	(1719, 6, '0-999-149', 5, 144),
	(1720, 6, '0-999-150', 3, 145),
	(1721, 6, '0-999-151', 2, 146),
	(1722, 6, '0-999-152', 15, 147),
	(1723, 6, '0-999-153', 15, 148),
	(1724, 6, '0-999-154', 16, 149),
	(1725, 6, '0-999-155', 16, 150),
	(1726, 6, '0-999-156', 14, 151),
	(1727, 6, '0-999-157', 4, 152),
	(1728, 6, '0-999-158', 20, 153),
	(1729, 6, '0-999-159', 3, 154),
	(1730, 6, '0-999-160', 4, 155),
	(1731, 6, '0-999-161', 10, 156),
	(1732, 6, '0-999-162', 3, 157),
	(1733, 6, '0-999-163', 3, 158),
	(1734, 6, '0-999-164', 2, 159),
	(1735, 6, '0-999-165', 6, 160),
	(1736, 6, '0-999-166', 20, 161),
	(1737, 6, '0-999-167', 20, 162),
	(1738, 6, '0-999-168', 20, 163),
	(1739, 6, '0-999-169', 4, 164),
	(1740, 6, '0-999-170', 4, 165),
	(1741, 6, '0-999-171', 8, 166),
	(1742, 6, '0-999-172', 1, 167),
	(1743, 6, '0-999-173', 17, 168),
	(1744, 6, '0-999-174', 0, 169),
	(1745, 6, '0-999-175', 0, 170),
	(1746, 6, '0-999-176', 27, 171),
	(1747, 6, '0-999-177', 0, 172),
	(1748, 6, '1-999-001', 15, 173),
	(1749, 6, '1-999-002', 3, 174),
	(1750, 6, '1-999-003', 3, 175),
	(1751, 6, '1-999-004', 135, 176),
	(1752, 6, '1-999-005', 135, 177),
	(1753, 6, '1-999-006', 6, 178),
	(1754, 6, '1-999-007', 4, 179),
	(1755, 6, '1-999-008', 3, 180),
	(1756, 6, '1-999-009', 8, 181),
	(1757, 6, '1-999-010', 12, 182),
	(1758, 6, '1-999-011', 8, 183),
	(1759, 6, '1-999-012', 0, 184),
	(1760, 6, '1-999-013', 6, 185),
	(1761, 6, '1-999-014', 9, 186),
	(1762, 6, '1-999-015', 100, 187),
	(1763, 6, '1-999-016', 90, 188),
	(1764, 6, '1-999-017', 40, 189),
	(1765, 6, '1-999-018', 130, 190),
	(1766, 6, '1-999-019', 135, 191),
	(1767, 6, '1-999-020', 93, 192),
	(1768, 6, '1-999-021', 43, 193),
	(1769, 6, '1-999-022', 100, 194),
	(1770, 6, '1-999-023', 120, 195),
	(1771, 6, '1-999-024', 17, 196),
	(1772, 6, '1-999-025', 16, 197),
	(1773, 6, '1-999-026', 17, 198),
	(1774, 6, '1-999-027', 110, 199),
	(1775, 6, '1-999-028', 30, 200),
	(1776, 6, '1-999-029', 15, 201),
	(1777, 6, '1-999-030', 80, 202),
	(1778, 6, '1-999-031', 80, 203),
	(1779, 6, '1-999-032', 50, 204),
	(1780, 6, '1-999-033', 130, 205),
	(1781, 6, '1-999-034', 110, 206),
	(1782, 6, '1-999-035', 55, 207),
	(1783, 6, '1-999-036', 115, 208),
	(1784, 6, '1-999-037', 130, 209),
	(1785, 6, '1-999-038', 80, 210),
	(1786, 6, '1-999-039', 20, 211),
	(1787, 6, '1-999-040', 10, 212),
	(1788, 6, '1-999-041', 3, 213),
	(1789, 6, '1-999-042', 135, 214),
	(1790, 6, '1-999-043', 15, 215),
	(1791, 6, '1-999-044', 40, 216),
	(1792, 6, '1-999-045', 90, 217),
	(1793, 6, '1-999-046', 130, 218),
	(1794, 6, '1-999-047', 130, 219),
	(1795, 6, '1-999-048', 10, 220),
	(1796, 6, '1-999-049', 15, 221),
	(1797, 6, '1-999-050', 20, 222),
	(1798, 6, '1-999-051', 15, 223),
	(1799, 6, '1-999-052', 3, 224),
	(1800, 6, '1-999-053', 16, 225),
	(1801, 6, '1-999-054', 16, 226),
	(1802, 6, '1-999-055', 12, 227),
	(1803, 6, '1-999-056', 10, 228),
	(1804, 6, '1-999-057', 70, 229),
	(1805, 6, '1-999-058', 200, 230),
	(1806, 6, '1-999-059', 10, 231),
	(1807, 6, '1-999-060', 10, 232),
	(1808, 6, '1-999-061', 10, 233),
	(1809, 6, '1-999-062', 2, 234),
	(1810, 6, '1-999-063', 3, 235),
	(1811, 6, '1-999-064', 8, 236),
	(1812, 6, '1-999-065', 0, 237),
	(1813, 6, '1-999-066', 0, 238),
	(1814, 6, '1-999-077', 0, 239),
	(1815, 6, '2-999-000', 5, 240),
	(1816, 6, '2-999-001', 7, 241),
	(1817, 6, '2-999-002', 7, 242),
	(1818, 6, '2-999-003', 30, 243),
	(1819, 6, '2-999-004', 6, 244),
	(1820, 6, '2-999-005', 2, 245),
	(1821, 6, '2-999-006', 32, 246),
	(1822, 6, '2-999-007', 5, 247),
	(1823, 6, '2-999-008', 10, 248),
	(1824, 6, '2-999-009', 2, 249),
	(1825, 6, '2-999-012', 10, 250),
	(1826, 6, '2-999-013', 20, 251),
	(1827, 6, '2-999-014', 3, 252),
	(1828, 6, '2-999-015', 3, 253),
	(1829, 6, '2-999-016', 4, 254),
	(1830, 6, '2-999-017', 3, 255),
	(1831, 6, '2-999-018', 5, 256),
	(1832, 6, '2-999-020', 25, 257),
	(1833, 6, '2-999-021', 5, 258),
	(1834, 6, '2-999-022', 14, 259),
	(1835, 6, '2-999-023', 20, 260),
	(1836, 6, '2-999-024', 30, 261),
	(1837, 6, '2-999-025', 20, 262),
	(1838, 6, '2-999-026', 2, 263),
	(1839, 6, '2-999-027', 15, 264),
	(1840, 6, '2-999-028', 25, 265),
	(1841, 6, '2-999-029', 5, 266),
	(1842, 6, '2-999-030', 5, 267),
	(1843, 6, '2-999-031', 10, 268),
	(1844, 6, '2-999-032', 6, 269),
	(1845, 6, '2-999-033', 6, 270),
	(1846, 6, '2-999-034', 4, 271),
	(1847, 6, '2-999-035', 3, 272),
	(1848, 6, '2-999-036', 6, 273),
	(1849, 6, '2-999-037', 1, 274),
	(1850, 6, '2-999-038', 4, 275),
	(1851, 6, '2-999-039', 3, 276),
	(1852, 6, '2-999-041', 130, 277),
	(1853, 6, '2-999-042', 20, 278),
	(1854, 6, '2-999-043', 20, 279),
	(1855, 6, '2-999-044', 1, 280),
	(1856, 6, '2-999-045', 3, 281),
	(1857, 6, '2-999-046', 1, 282),
	(1858, 6, '2-999-047', 15, 283),
	(1859, 6, '2-999-048', 5, 284),
	(1860, 6, '2-999-049', 15, 285),
	(1861, 6, '2-999-050', 2, 286),
	(1862, 6, '2-999-051', 2, 287),
	(1863, 6, '2-999-052', 15, 288),
	(1864, 6, '2-999-053', 3, 289),
	(1865, 6, '2-999-054', 3, 290),
	(1866, 6, '2-999-055', 1, 291),
	(1867, 6, '2-999-056', 12, 292),
	(1868, 6, '2-999-057', 10, 293),
	(1869, 6, '2-999-058', 10, 294),
	(1870, 6, '2-999-059', 15, 295),
	(1871, 6, '2-999-061', 8, 296),
	(1872, 6, '2-999-062', 10, 297),
	(1873, 6, '2-999-063', 10, 298),
	(1874, 6, '2-999-065', 10, 299),
	(1875, 6, '2-999-066', 10, 300),
	(1876, 6, '2-999-067', 7, 301),
	(1877, 6, '2-999-070', 35, 302),
	(1878, 6, '2-999-071', 15, 303),
	(1879, 6, '2-999-074', 6, 304),
	(1880, 6, '2-999-075', 0, 305),
	(1881, 6, '2-999-076', 0, 306),
	(1882, 6, '2-999-077', 3, 307),
	(1883, 6, '2-999-078', 10, 308),
	(1884, 6, '2-999-079', 0, 309),
	(1885, 6, '2-999-080', 0, 310),
	(1886, 6, '2-999-081', 0, 311),
	(1887, 6, '2-999-082', 3, 312),
	(1888, 6, '2-999-083', 3, 313),
	(1889, 6, '2-999-084', 0, 314),
	(1890, 6, '2-999-085', 0, 315),
	(1891, 7, '0-999-000', 12, 1),
	(1892, 7, '0-999-001', 5, 2),
	(1893, 7, '0-999-002', 35, 3),
	(1894, 7, '0-999-003', 7, 4),
	(1895, 7, '0-999-004', 4, 5),
	(1896, 7, '0-999-005', 4, 6),
	(1897, 7, '0-999-006', 0, 7),
	(1898, 7, '0-999-007', 3, 8),
	(1899, 7, '0-999-008', 2, 9),
	(1900, 7, '0-999-010', 3, 10),
	(1901, 7, '0-999-011', 6, 11),
	(1902, 7, '0-999-013', 5, 12),
	(1903, 7, '0-999-014', 5, 13),
	(1904, 7, '0-999-015', 2, 14),
	(1905, 7, '0-999-016', 2, 15),
	(1906, 7, '0-999-017', 0, 16),
	(1907, 7, '0-999-018', 2, 17),
	(1908, 7, '0-999-019', 0, 18),
	(1909, 7, '0-999-020', 0, 19),
	(1910, 7, '0-999-021', 2, 20),
	(1911, 7, '0-999-022', 2, 21),
	(1912, 7, '0-999-023', 2, 22),
	(1913, 7, '0-999-024', 1, 23),
	(1914, 7, '0-999-025', 1, 24),
	(1915, 7, '0-999-026', 1, 25),
	(1916, 7, '0-999-027', 1, 26),
	(1917, 7, '0-999-028', 0, 27),
	(1918, 7, '0-999-029', 1, 28),
	(1919, 7, '0-999-030', 8, 29),
	(1920, 7, '0-999-031', 20, 30),
	(1921, 7, '0-999-032', 1, 31),
	(1922, 7, '0-999-033', 4, 32),
	(1923, 7, '0-999-034', 3, 33),
	(1924, 7, '0-999-035', 4, 34),
	(1925, 7, '0-999-036', 0, 35),
	(1926, 7, '0-999-037', 5, 36),
	(1927, 7, '0-999-039', 0, 37),
	(1928, 7, '0-999-041', 0, 38),
	(1929, 7, '0-999-042', 0, 39),
	(1930, 7, '0-999-043', 0, 40),
	(1931, 7, '0-999-044', 15, 41),
	(1932, 7, '0-999-045', 0, 42),
	(1933, 7, '0-999-046', 0, 43),
	(1934, 7, '0-999-047', 0, 44),
	(1935, 7, '0-999-048', 0, 45),
	(1936, 7, '0-999-049', 0, 46),
	(1937, 7, '0-999-050', 0, 47),
	(1938, 7, '0-999-051', 0, 48),
	(1939, 7, '0-999-052', 0, 49),
	(1940, 7, '0-999-053', 0, 50),
	(1941, 7, '0-999-054', 0, 51),
	(1942, 7, '0-999-055', 0, 52),
	(1943, 7, '0-999-056', 0, 53),
	(1944, 7, '0-999-057', 0, 54),
	(1945, 7, '0-999-058', 0, 55),
	(1946, 7, '0-999-059', 0, 56),
	(1947, 7, '0-999-060', 0, 57),
	(1948, 7, '0-999-061', 0, 58),
	(1949, 7, '0-999-062', 0, 59),
	(1950, 7, '0-999-063', 0, 60),
	(1951, 7, '0-999-064', 0, 61),
	(1952, 7, '0-999-065', 0, 62),
	(1953, 7, '0-999-066', 0, 63),
	(1954, 7, '0-999-067', 0, 64),
	(1955, 7, '0-999-068', 0, 65),
	(1956, 7, '0-999-069', 0, 66),
	(1957, 7, '0-999-070', 0, 67),
	(1958, 7, '0-999-071', 0, 68),
	(1959, 7, '0-999-072', 0, 69),
	(1960, 7, '0-999-073', 0, 70),
	(1961, 7, '0-999-074', 0, 71),
	(1962, 7, '0-999-075', 0, 72),
	(1963, 7, '0-999-076', 0, 73),
	(1964, 7, '0-999-077', 0, 74),
	(1965, 7, '0-999-078', 0, 75),
	(1966, 7, '0-999-079', 0, 76),
	(1967, 7, '0-999-080', 0, 77),
	(1968, 7, '0-999-081', 0, 78),
	(1969, 7, '0-999-082', 0, 79),
	(1970, 7, '0-999-083', 0, 80),
	(1971, 7, '0-999-084', 0, 81),
	(1972, 7, '0-999-085', 0, 82),
	(1973, 7, '0-999-086', 0, 83),
	(1974, 7, '0-999-087', 0, 84),
	(1975, 7, '0-999-088', 0, 85),
	(1976, 7, '0-999-089', 0, 86),
	(1977, 7, '0-999-090', 0, 87),
	(1978, 7, '0-999-091', 0, 88),
	(1979, 7, '0-999-092', 0, 89),
	(1980, 7, '0-999-093', 0, 90),
	(1981, 7, '0-999-094', 0, 91),
	(1982, 7, '0-999-095', 0, 92),
	(1983, 7, '0-999-096', 0, 93),
	(1984, 7, '0-999-097', 0, 94),
	(1985, 7, '0-999-098', 0, 95),
	(1986, 7, '0-999-099', 0, 96),
	(1987, 7, '0-999-101', 0, 97),
	(1988, 7, '0-999-102', 0, 98),
	(1989, 7, '0-999-103', 0, 99),
	(1990, 7, '0-999-104', 0, 100),
	(1991, 7, '0-999-105', 0, 101),
	(1992, 7, '0-999-106', 0, 102),
	(1993, 7, '0-999-107', 0, 103),
	(1994, 7, '0-999-108', 0, 104),
	(1995, 7, '0-999-109', 0, 105),
	(1996, 7, '0-999-110', 0, 106),
	(1997, 7, '0-999-111', 0, 107),
	(1998, 7, '0-999-112', 0, 108),
	(1999, 7, '0-999-113', 0, 109),
	(2000, 7, '0-999-114', 0, 110),
	(2001, 7, '0-999-115', 0, 111),
	(2002, 7, '0-999-116', 0, 112),
	(2003, 7, '0-999-117', 0, 113),
	(2004, 7, '0-999-118', 0, 114),
	(2005, 7, '0-999-119', 0, 115),
	(2006, 7, '0-999-120', 0, 116),
	(2007, 7, '0-999-121', 0, 117),
	(2008, 7, '0-999-122', 0, 118),
	(2009, 7, '0-999-123', 0, 119),
	(2010, 7, '0-999-124', 0, 120),
	(2011, 7, '0-999-125', 0, 121),
	(2012, 7, '0-999-126', 0, 122),
	(2013, 7, '0-999-127', 0, 123),
	(2014, 7, '0-999-128', 0, 124),
	(2015, 7, '0-999-129', 0, 125),
	(2016, 7, '0-999-130', 0, 126),
	(2017, 7, '0-999-131', 0, 127),
	(2018, 7, '0-999-132', 0, 128),
	(2019, 7, '0-999-133', 5, 129),
	(2020, 7, '0-999-134', 0, 130),
	(2021, 7, '0-999-135', 0, 131),
	(2022, 7, '0-999-136', 0, 132),
	(2023, 7, '0-999-137', 0, 133),
	(2024, 7, '0-999-138', 0, 134),
	(2025, 7, '0-999-139', 0, 135),
	(2026, 7, '0-999-140', 0, 136),
	(2027, 7, '0-999-141', 0, 137),
	(2028, 7, '0-999-142', 0, 138),
	(2029, 7, '0-999-144', 0, 139),
	(2030, 7, '0-999-145', 0, 140),
	(2031, 7, '0-999-146', 0, 141),
	(2032, 7, '0-999-147', 0, 142),
	(2033, 7, '0-999-148', 0, 143),
	(2034, 7, '0-999-149', 0, 144),
	(2035, 7, '0-999-150', 0, 145),
	(2036, 7, '0-999-151', 0, 146),
	(2037, 7, '0-999-152', 0, 147),
	(2038, 7, '0-999-153', 0, 148),
	(2039, 7, '0-999-154', 0, 149),
	(2040, 7, '0-999-155', 0, 150),
	(2041, 7, '0-999-156', 0, 151),
	(2042, 7, '0-999-157', 0, 152),
	(2043, 7, '0-999-158', 0, 153),
	(2044, 7, '0-999-159', 0, 154),
	(2045, 7, '0-999-160', 0, 155),
	(2046, 7, '0-999-161', 0, 156),
	(2047, 7, '0-999-162', 0, 157),
	(2048, 7, '0-999-163', 0, 158),
	(2049, 7, '0-999-164', 0, 159),
	(2050, 7, '0-999-165', 0, 160),
	(2051, 7, '0-999-166', 0, 161),
	(2052, 7, '0-999-167', 0, 162),
	(2053, 7, '0-999-168', 0, 163),
	(2054, 7, '0-999-169', 0, 164),
	(2055, 7, '0-999-170', 0, 165),
	(2056, 7, '0-999-171', 0, 166),
	(2057, 7, '0-999-172', 0, 167),
	(2058, 7, '0-999-173', 0, 168),
	(2059, 7, '0-999-174', 3, 169),
	(2060, 7, '0-999-175', 5, 170),
	(2061, 7, '0-999-176', 0, 171),
	(2062, 7, '0-999-177', 2, 172),
	(2063, 7, '1-999-001', 10, 173),
	(2064, 7, '1-999-002', 1, 174),
	(2065, 7, '1-999-003', 3, 175),
	(2066, 7, '1-999-004', 90, 176),
	(2067, 7, '1-999-005', 94, 177),
	(2068, 7, '1-999-006', 2, 178),
	(2069, 7, '1-999-007', 6, 179),
	(2070, 7, '1-999-008', 3, 180),
	(2071, 7, '1-999-009', 7, 181),
	(2072, 7, '1-999-010', 7, 182),
	(2073, 7, '1-999-011', 4, 183),
	(2074, 7, '1-999-012', 5, 184),
	(2075, 7, '1-999-013', 2, 185),
	(2076, 7, '1-999-014', 3, 186),
	(2077, 7, '1-999-015', 60, 187),
	(2078, 7, '1-999-016', 30, 188),
	(2079, 7, '1-999-017', 20, 189),
	(2080, 7, '1-999-018', 98, 190),
	(2081, 7, '1-999-019', 101, 191),
	(2082, 7, '1-999-020', 33, 192),
	(2083, 7, '1-999-021', 33, 193),
	(2084, 7, '1-999-022', 63, 194),
	(2085, 7, '1-999-023', 11, 195),
	(2086, 7, '1-999-024', 8, 196),
	(2087, 7, '1-999-025', 8, 197),
	(2088, 7, '1-999-026', 8, 198),
	(2089, 7, '1-999-027', 45, 199),
	(2090, 7, '1-999-028', 30, 200),
	(2091, 7, '1-999-029', 25, 201),
	(2092, 7, '1-999-030', 30, 202),
	(2093, 7, '1-999-031', 31, 203),
	(2094, 7, '1-999-032', 45, 204),
	(2095, 7, '1-999-033', 60, 205),
	(2096, 7, '1-999-034', 45, 206),
	(2097, 7, '1-999-035', 60, 207),
	(2098, 7, '1-999-036', 60, 208),
	(2099, 7, '1-999-037', 70, 209),
	(2100, 7, '1-999-038', 45, 210),
	(2101, 7, '1-999-039', 10, 211),
	(2102, 7, '1-999-040', 6, 212),
	(2103, 7, '1-999-041', 3, 213),
	(2104, 7, '1-999-042', 98, 214),
	(2105, 7, '1-999-043', 2, 215),
	(2106, 7, '1-999-044', 33, 216),
	(2107, 7, '1-999-045', 33, 217),
	(2108, 7, '1-999-046', 92, 218),
	(2109, 7, '1-999-047', 98, 219),
	(2110, 7, '1-999-048', 7, 220),
	(2111, 7, '1-999-049', 10, 221),
	(2112, 7, '1-999-050', 7, 222),
	(2113, 7, '1-999-051', 8, 223),
	(2114, 7, '1-999-052', 4, 224),
	(2115, 7, '1-999-053', 10, 225),
	(2116, 7, '1-999-054', 9, 226),
	(2117, 7, '1-999-055', 10, 227),
	(2118, 7, '1-999-056', 9, 228),
	(2119, 7, '1-999-057', 26, 229),
	(2120, 7, '1-999-058', 174, 230),
	(2121, 7, '1-999-059', 6, 231),
	(2122, 7, '1-999-060', 5, 232),
	(2123, 7, '1-999-061', 4, 233),
	(2124, 7, '1-999-062', 3, 234),
	(2125, 7, '1-999-063', 1, 235),
	(2126, 7, '1-999-064', 0, 236),
	(2127, 7, '1-999-065', 0, 237),
	(2128, 7, '1-999-066', 0, 238),
	(2129, 7, '1-999-077', 0, 239),
	(2130, 7, '2-999-000', 7, 240),
	(2131, 7, '2-999-001', 3, 241),
	(2132, 7, '2-999-002', 3, 242),
	(2133, 7, '2-999-003', 20, 243),
	(2134, 7, '2-999-004', 2, 244),
	(2135, 7, '2-999-005', 2, 245),
	(2136, 7, '2-999-006', 25, 246),
	(2137, 7, '2-999-007', 3, 247),
	(2138, 7, '2-999-008', 5, 248),
	(2139, 7, '2-999-009', 1, 249),
	(2140, 7, '2-999-012', 6, 250),
	(2141, 7, '2-999-013', 8, 251),
	(2142, 7, '2-999-014', 5, 252),
	(2143, 7, '2-999-015', 5, 253),
	(2144, 7, '2-999-016', 6, 254),
	(2145, 7, '2-999-017', 4, 255),
	(2146, 7, '2-999-018', 5, 256),
	(2147, 7, '2-999-020', 6, 257),
	(2148, 7, '2-999-021', 8, 258),
	(2149, 7, '2-999-022', 13, 259),
	(2150, 7, '2-999-023', 20, 260),
	(2151, 7, '2-999-024', 30, 261),
	(2152, 7, '2-999-025', 20, 262),
	(2153, 7, '2-999-026', 2, 263),
	(2154, 7, '2-999-027', 1, 264),
	(2155, 7, '2-999-028', 5, 265),
	(2156, 7, '2-999-029', 5, 266),
	(2157, 7, '2-999-030', 5, 267),
	(2158, 7, '2-999-031', 8, 268),
	(2159, 7, '2-999-032', 6, 269),
	(2160, 7, '2-999-033', 6, 270),
	(2161, 7, '2-999-034', 4, 271),
	(2162, 7, '2-999-035', 3, 272),
	(2163, 7, '2-999-036', 4, 273),
	(2164, 7, '2-999-037', 1, 274),
	(2165, 7, '2-999-038', 5, 275),
	(2166, 7, '2-999-039', 3, 276),
	(2167, 7, '2-999-041', 100, 277),
	(2168, 7, '2-999-042', 8, 278),
	(2169, 7, '2-999-043', 0, 279),
	(2170, 7, '2-999-044', 2, 280),
	(2171, 7, '2-999-045', 2, 281),
	(2172, 7, '2-999-046', 1, 282),
	(2173, 7, '2-999-047', 6, 283),
	(2174, 7, '2-999-048', 0, 284),
	(2175, 7, '2-999-049', 5, 285),
	(2176, 7, '2-999-050', 5, 286),
	(2177, 7, '2-999-051', 1, 287),
	(2178, 7, '2-999-052', 3, 288),
	(2179, 7, '2-999-053', 2, 289),
	(2180, 7, '2-999-054', 4, 290),
	(2181, 7, '2-999-055', 2, 291),
	(2182, 7, '2-999-056', 7, 292),
	(2183, 7, '2-999-057', 5, 293),
	(2184, 7, '2-999-058', 4, 294),
	(2185, 7, '2-999-059', 10, 295),
	(2186, 7, '2-999-061', 10, 296),
	(2187, 7, '2-999-062', 4, 297),
	(2188, 7, '2-999-063', 5, 298),
	(2189, 7, '2-999-065', 3, 299),
	(2190, 7, '2-999-066', 3, 300),
	(2191, 7, '2-999-067', 7, 301),
	(2192, 7, '2-999-070', 8, 302),
	(2193, 7, '2-999-071', 8, 303),
	(2194, 7, '2-999-074', 1, 304),
	(2195, 7, '2-999-075', 5, 305),
	(2196, 7, '2-999-076', 7, 306),
	(2197, 7, '2-999-077', 2, 307),
	(2198, 7, '2-999-078', 0, 308),
	(2199, 7, '2-999-079', 20, 309),
	(2200, 7, '2-999-080', 20, 310),
	(2201, 7, '2-999-081', 0, 311),
	(2202, 7, '2-999-082', 0, 312),
	(2203, 7, '2-999-083', 3, 313),
	(2204, 7, '2-999-084', 3, 314),
	(2205, 7, '2-999-085', 10, 315),
	(2206, 8, '0-999-000', 15, 1),
	(2207, 8, '0-999-001', 7, 2),
	(2208, 8, '0-999-002', 37, 3),
	(2209, 8, '0-999-003', 6, 4),
	(2210, 8, '0-999-004', 3, 5),
	(2211, 8, '0-999-005', 6, 6),
	(2212, 8, '0-999-006', 0, 7),
	(2213, 8, '0-999-007', 2, 8),
	(2214, 8, '0-999-008', 2, 9),
	(2215, 8, '0-999-010', 1, 10),
	(2216, 8, '0-999-011', 7, 11),
	(2217, 8, '0-999-013', 3, 12),
	(2218, 8, '0-999-014', 5, 13),
	(2219, 8, '0-999-015', 2, 14),
	(2220, 8, '0-999-016', 2, 15),
	(2221, 8, '0-999-017', 0, 16),
	(2222, 8, '0-999-018', 0, 17),
	(2223, 8, '0-999-019', 0, 18),
	(2224, 8, '0-999-020', 0, 19),
	(2225, 8, '0-999-021', 0, 20),
	(2226, 8, '0-999-022', 2, 21),
	(2227, 8, '0-999-023', 2, 22),
	(2228, 8, '0-999-024', 1, 23),
	(2229, 8, '0-999-025', 1, 24),
	(2230, 8, '0-999-026', 1, 25),
	(2231, 8, '0-999-027', 1, 26),
	(2232, 8, '0-999-028', 0, 27),
	(2233, 8, '0-999-029', 2, 28),
	(2234, 8, '0-999-030', 8, 29),
	(2235, 8, '0-999-031', 20, 30),
	(2236, 8, '0-999-032', 1, 31),
	(2237, 8, '0-999-033', 4, 32),
	(2238, 8, '0-999-034', 3, 33),
	(2239, 8, '0-999-035', 4, 34),
	(2240, 8, '0-999-036', 60, 35),
	(2241, 8, '0-999-037', 0, 36),
	(2242, 8, '0-999-039', 0, 37),
	(2243, 8, '0-999-041', 0, 38),
	(2244, 8, '0-999-042', 0, 39),
	(2245, 8, '0-999-043', 0, 40),
	(2246, 8, '0-999-044', 15, 41),
	(2247, 8, '0-999-045', 3, 42),
	(2248, 8, '0-999-046', 0, 43),
	(2249, 8, '0-999-047', 0, 44),
	(2250, 8, '0-999-048', 0, 45),
	(2251, 8, '0-999-049', 0, 46),
	(2252, 8, '0-999-050', 0, 47),
	(2253, 8, '0-999-051', 0, 48),
	(2254, 8, '0-999-052', 0, 49),
	(2255, 8, '0-999-053', 0, 50),
	(2256, 8, '0-999-054', 0, 51),
	(2257, 8, '0-999-055', 0, 52),
	(2258, 8, '0-999-056', 0, 53),
	(2259, 8, '0-999-057', 0, 54),
	(2260, 8, '0-999-058', 0, 55),
	(2261, 8, '0-999-059', 0, 56),
	(2262, 8, '0-999-060', 0, 57),
	(2263, 8, '0-999-061', 0, 58),
	(2264, 8, '0-999-062', 0, 59),
	(2265, 8, '0-999-063', 0, 60),
	(2266, 8, '0-999-064', 0, 61),
	(2267, 8, '0-999-065', 0, 62),
	(2268, 8, '0-999-066', 0, 63),
	(2269, 8, '0-999-067', 0, 64),
	(2270, 8, '0-999-068', 0, 65),
	(2271, 8, '0-999-069', 0, 66),
	(2272, 8, '0-999-070', 0, 67),
	(2273, 8, '0-999-071', 0, 68),
	(2274, 8, '0-999-072', 0, 69),
	(2275, 8, '0-999-073', 0, 70),
	(2276, 8, '0-999-074', 0, 71),
	(2277, 8, '0-999-075', 0, 72),
	(2278, 8, '0-999-076', 0, 73),
	(2279, 8, '0-999-077', 0, 74),
	(2280, 8, '0-999-078', 0, 75),
	(2281, 8, '0-999-079', 0, 76),
	(2282, 8, '0-999-080', 0, 77),
	(2283, 8, '0-999-081', 0, 78),
	(2284, 8, '0-999-082', 0, 79),
	(2285, 8, '0-999-083', 0, 80),
	(2286, 8, '0-999-084', 0, 81),
	(2287, 8, '0-999-085', 0, 82),
	(2288, 8, '0-999-086', 0, 83),
	(2289, 8, '0-999-087', 0, 84),
	(2290, 8, '0-999-088', 0, 85),
	(2291, 8, '0-999-089', 0, 86),
	(2292, 8, '0-999-090', 0, 87),
	(2293, 8, '0-999-091', 0, 88),
	(2294, 8, '0-999-092', 0, 89),
	(2295, 8, '0-999-093', 0, 90),
	(2296, 8, '0-999-094', 0, 91),
	(2297, 8, '0-999-095', 0, 92),
	(2298, 8, '0-999-096', 0, 93),
	(2299, 8, '0-999-097', 0, 94),
	(2300, 8, '0-999-098', 0, 95),
	(2301, 8, '0-999-099', 0, 96),
	(2302, 8, '0-999-101', 0, 97),
	(2303, 8, '0-999-102', 0, 98),
	(2304, 8, '0-999-103', 0, 99),
	(2305, 8, '0-999-104', 0, 100),
	(2306, 8, '0-999-105', 0, 101),
	(2307, 8, '0-999-106', 0, 102),
	(2308, 8, '0-999-107', 0, 103),
	(2309, 8, '0-999-108', 0, 104),
	(2310, 8, '0-999-109', 0, 105),
	(2311, 8, '0-999-110', 0, 106),
	(2312, 8, '0-999-111', 0, 107),
	(2313, 8, '0-999-112', 0, 108),
	(2314, 8, '0-999-113', 0, 109),
	(2315, 8, '0-999-114', 0, 110),
	(2316, 8, '0-999-115', 0, 111),
	(2317, 8, '0-999-116', 0, 112),
	(2318, 8, '0-999-117', 0, 113),
	(2319, 8, '0-999-118', 0, 114),
	(2320, 8, '0-999-119', 0, 115),
	(2321, 8, '0-999-120', 0, 116),
	(2322, 8, '0-999-121', 0, 117),
	(2323, 8, '0-999-122', 0, 118),
	(2324, 8, '0-999-123', 0, 119),
	(2325, 8, '0-999-124', 0, 120),
	(2326, 8, '0-999-125', 0, 121),
	(2327, 8, '0-999-126', 0, 122),
	(2328, 8, '0-999-127', 0, 123),
	(2329, 8, '0-999-128', 0, 124),
	(2330, 8, '0-999-129', 0, 125),
	(2331, 8, '0-999-130', 0, 126),
	(2332, 8, '0-999-131', 0, 127),
	(2333, 8, '0-999-132', 0, 128),
	(2334, 8, '0-999-133', 5, 129),
	(2335, 8, '0-999-134', 0, 130),
	(2336, 8, '0-999-135', 0, 131),
	(2337, 8, '0-999-136', 0, 132),
	(2338, 8, '0-999-137', 0, 133),
	(2339, 8, '0-999-138', 0, 134),
	(2340, 8, '0-999-139', 0, 135),
	(2341, 8, '0-999-140', 0, 136),
	(2342, 8, '0-999-141', 0, 137),
	(2343, 8, '0-999-142', 0, 138),
	(2344, 8, '0-999-144', 0, 139),
	(2345, 8, '0-999-145', 0, 140),
	(2346, 8, '0-999-146', 0, 141),
	(2347, 8, '0-999-147', 0, 142),
	(2348, 8, '0-999-148', 0, 143),
	(2349, 8, '0-999-149', 0, 144),
	(2350, 8, '0-999-150', 0, 145),
	(2351, 8, '0-999-151', 0, 146),
	(2352, 8, '0-999-152', 0, 147),
	(2353, 8, '0-999-153', 0, 148),
	(2354, 8, '0-999-154', 0, 149),
	(2355, 8, '0-999-155', 0, 150),
	(2356, 8, '0-999-156', 0, 151),
	(2357, 8, '0-999-157', 0, 152),
	(2358, 8, '0-999-158', 0, 153),
	(2359, 8, '0-999-159', 0, 154),
	(2360, 8, '0-999-160', 0, 155),
	(2361, 8, '0-999-161', 0, 156),
	(2362, 8, '0-999-162', 0, 157),
	(2363, 8, '0-999-163', 0, 158),
	(2364, 8, '0-999-164', 0, 159),
	(2365, 8, '0-999-165', 0, 160),
	(2366, 8, '0-999-166', 0, 161),
	(2367, 8, '0-999-167', 0, 162),
	(2368, 8, '0-999-168', 0, 163),
	(2369, 8, '0-999-169', 0, 164),
	(2370, 8, '0-999-170', 0, 165),
	(2371, 8, '0-999-171', 0, 166),
	(2372, 8, '0-999-172', 0, 167),
	(2373, 8, '0-999-173', 0, 168),
	(2374, 8, '0-999-174', 0, 169),
	(2375, 8, '0-999-175', 0, 170),
	(2376, 8, '0-999-176', 0, 171),
	(2377, 8, '0-999-177', 0, 172),
	(2378, 8, '1-999-001', 15, 173),
	(2379, 8, '1-999-002', 4, 174),
	(2380, 8, '1-999-003', 2, 175),
	(2381, 8, '1-999-004', 84, 176),
	(2382, 8, '1-999-005', 88, 177),
	(2383, 8, '1-999-006', 3, 178),
	(2384, 8, '1-999-007', 9, 179),
	(2385, 8, '1-999-008', 3, 180),
	(2386, 8, '1-999-009', 9, 181),
	(2387, 8, '1-999-010', 10, 182),
	(2388, 8, '1-999-011', 4, 183),
	(2389, 8, '1-999-012', 5, 184),
	(2390, 8, '1-999-013', 2, 185),
	(2391, 8, '1-999-014', 3, 186),
	(2392, 8, '1-999-015', 45, 187),
	(2393, 8, '1-999-016', 30, 188),
	(2394, 8, '1-999-017', 30, 189),
	(2395, 8, '1-999-018', 97, 190),
	(2396, 8, '1-999-019', 97, 191),
	(2397, 8, '1-999-020', 35, 192),
	(2398, 8, '1-999-021', 42, 193),
	(2399, 8, '1-999-022', 55, 194),
	(2400, 8, '1-999-023', 16, 195),
	(2401, 8, '1-999-024', 8, 196),
	(2402, 8, '1-999-025', 9, 197),
	(2403, 8, '1-999-026', 9, 198),
	(2404, 8, '1-999-027', 44, 199),
	(2405, 8, '1-999-028', 15, 200),
	(2406, 8, '1-999-029', 15, 201),
	(2407, 8, '1-999-030', 19, 202),
	(2408, 8, '1-999-031', 20, 203),
	(2409, 8, '1-999-032', 44, 204),
	(2410, 8, '1-999-033', 70, 205),
	(2411, 8, '1-999-034', 44, 206),
	(2412, 8, '1-999-035', 44, 207),
	(2413, 8, '1-999-036', 44, 208),
	(2414, 8, '1-999-037', 70, 209),
	(2415, 8, '1-999-038', 44, 210),
	(2416, 8, '1-999-039', 15, 211),
	(2417, 8, '1-999-040', 10, 212),
	(2418, 8, '1-999-041', 3, 213),
	(2419, 8, '1-999-042', 100, 214),
	(2420, 8, '1-999-043', 2, 215),
	(2421, 8, '1-999-044', 40, 216),
	(2422, 8, '1-999-045', 40, 217),
	(2423, 8, '1-999-046', 100, 218),
	(2424, 8, '1-999-047', 100, 219),
	(2425, 8, '1-999-048', 10, 220),
	(2426, 8, '1-999-049', 15, 221),
	(2427, 8, '1-999-050', 14, 222),
	(2428, 8, '1-999-051', 17, 223),
	(2429, 8, '1-999-052', 5, 224),
	(2430, 8, '1-999-053', 15, 225),
	(2431, 8, '1-999-054', 15, 226),
	(2432, 8, '1-999-055', 15, 227),
	(2433, 8, '1-999-056', 15, 228),
	(2434, 8, '1-999-057', 40, 229),
	(2435, 8, '1-999-058', 180, 230),
	(2436, 8, '1-999-059', 9, 231),
	(2437, 8, '1-999-060', 9, 232),
	(2438, 8, '1-999-061', 9, 233),
	(2439, 8, '1-999-062', 2, 234),
	(2440, 8, '1-999-063', 1, 235),
	(2441, 8, '1-999-064', 0, 236),
	(2442, 8, '1-999-065', 0, 237),
	(2443, 8, '1-999-066', 0, 238),
	(2444, 8, '1-999-077', 0, 239),
	(2445, 8, '2-999-000', 6, 240),
	(2446, 8, '2-999-001', 3, 241),
	(2447, 8, '2-999-002', 3, 242),
	(2448, 8, '2-999-003', 25, 243),
	(2449, 8, '2-999-004', 6, 244),
	(2450, 8, '2-999-005', 25, 245),
	(2451, 8, '2-999-006', 4, 246),
	(2452, 8, '2-999-007', 6, 247),
	(2453, 8, '2-999-008', 2, 248),
	(2454, 8, '2-999-009', 0, 249),
	(2455, 8, '2-999-012', 7, 250),
	(2456, 8, '2-999-013', 7, 251),
	(2457, 8, '2-999-014', 3, 252),
	(2458, 8, '2-999-015', 3, 253),
	(2459, 8, '2-999-016', 4, 254),
	(2460, 8, '2-999-017', 3, 255),
	(2461, 8, '2-999-018', 4, 256),
	(2462, 8, '2-999-020', 5, 257),
	(2463, 8, '2-999-021', 4, 258),
	(2464, 8, '2-999-022', 7, 259),
	(2465, 8, '2-999-023', 20, 260),
	(2466, 8, '2-999-024', 28, 261),
	(2467, 8, '2-999-025', 18, 262),
	(2468, 8, '2-999-026', 2, 263),
	(2469, 8, '2-999-027', 1, 264),
	(2470, 8, '2-999-028', 5, 265),
	(2471, 8, '2-999-029', 5, 266),
	(2472, 8, '2-999-030', 5, 267),
	(2473, 8, '2-999-031', 8, 268),
	(2474, 8, '2-999-032', 6, 269),
	(2475, 8, '2-999-033', 6, 270),
	(2476, 8, '2-999-034', 4, 271),
	(2477, 8, '2-999-035', 3, 272),
	(2478, 8, '2-999-036', 6, 273),
	(2479, 8, '2-999-037', 1, 274),
	(2480, 8, '2-999-038', 4, 275),
	(2481, 8, '2-999-039', 3, 276),
	(2482, 8, '2-999-041', 100, 277),
	(2483, 8, '2-999-042', 10, 278),
	(2484, 8, '2-999-043', 0, 279),
	(2485, 8, '2-999-044', 1, 280),
	(2486, 8, '2-999-045', 2, 281),
	(2487, 8, '2-999-046', 1, 282),
	(2488, 8, '2-999-047', 5, 283),
	(2489, 8, '2-999-048', 1, 284),
	(2490, 8, '2-999-049', 5, 285),
	(2491, 8, '2-999-050', 2, 286),
	(2492, 8, '2-999-051', 2, 287),
	(2493, 8, '2-999-052', 0, 288),
	(2494, 8, '2-999-053', 0, 289),
	(2495, 8, '2-999-054', 1, 290),
	(2496, 8, '2-999-055', 1, 291),
	(2497, 8, '2-999-056', 7, 292),
	(2498, 8, '2-999-057', 5, 293),
	(2499, 8, '2-999-058', 10, 294),
	(2500, 8, '2-999-059', 15, 295),
	(2501, 8, '2-999-061', 15, 296),
	(2502, 8, '2-999-062', 6, 297),
	(2503, 8, '2-999-063', 5, 298),
	(2504, 8, '2-999-065', 10, 299),
	(2505, 8, '2-999-066', 5, 300),
	(2506, 8, '2-999-067', 7, 301),
	(2507, 8, '2-999-070', 20, 302),
	(2508, 8, '2-999-071', 5, 303),
	(2509, 8, '2-999-074', 1, 304),
	(2510, 8, '2-999-075', 3, 305),
	(2511, 8, '2-999-076', 6, 306),
	(2512, 8, '2-999-077', 20, 307),
	(2513, 8, '2-999-078', 10, 308),
	(2514, 8, '2-999-079', 20, 309),
	(2515, 8, '2-999-080', 5, 310),
	(2516, 8, '2-999-081', 0, 311),
	(2517, 8, '2-999-082', 0, 312),
	(2518, 8, '2-999-083', 3, 313),
	(2519, 8, '2-999-084', 0, 314),
	(2520, 8, '2-999-085', 0, 315),
	(2521, 9, '0-999-000', 60, 1),
	(2522, 9, '0-999-001', 20, 2),
	(2523, 9, '0-999-002', 75, 3),
	(2524, 9, '0-999-003', 0, 4),
	(2525, 9, '0-999-004', 5, 5),
	(2526, 9, '0-999-005', 17, 6),
	(2527, 9, '0-999-006', 0, 7),
	(2528, 9, '0-999-007', 0, 8),
	(2529, 9, '0-999-008', 5, 9),
	(2530, 9, '0-999-010', 7, 10),
	(2531, 9, '0-999-011', 10, 11),
	(2532, 9, '0-999-013', 2, 12),
	(2533, 9, '0-999-014', 6, 13),
	(2534, 9, '0-999-015', 1, 14),
	(2535, 9, '0-999-016', 2, 15),
	(2536, 9, '0-999-017', 0, 16),
	(2537, 9, '0-999-018', 2, 17),
	(2538, 9, '0-999-019', 0, 18),
	(2539, 9, '0-999-020', 0, 19),
	(2540, 9, '0-999-021', 2, 20),
	(2541, 9, '0-999-022', 3, 21),
	(2542, 9, '0-999-023', 2, 22),
	(2543, 9, '0-999-024', 2, 23),
	(2544, 9, '0-999-025', 1, 24),
	(2545, 9, '0-999-026', 1, 25),
	(2546, 9, '0-999-027', 1, 26),
	(2547, 9, '0-999-028', 0, 27),
	(2548, 9, '0-999-029', 10, 28),
	(2549, 9, '0-999-030', 10, 29),
	(2550, 9, '0-999-031', 20, 30),
	(2551, 9, '0-999-032', 1, 31),
	(2552, 9, '0-999-033', 4, 32),
	(2553, 9, '0-999-034', 2, 33),
	(2554, 9, '0-999-035', 11, 34),
	(2555, 9, '0-999-036', 40, 35),
	(2556, 9, '0-999-037', 0, 36),
	(2557, 9, '0-999-039', 0, 37),
	(2558, 9, '0-999-041', 0, 38),
	(2559, 9, '0-999-042', 0, 39),
	(2560, 9, '0-999-043', 0, 40),
	(2561, 9, '0-999-044', 10, 41),
	(2562, 9, '0-999-045', 6, 42),
	(2563, 9, '0-999-046', 4, 43),
	(2564, 9, '0-999-047', 8, 44),
	(2565, 9, '0-999-048', 5, 45),
	(2566, 9, '0-999-049', 15, 46),
	(2567, 9, '0-999-050', 10, 47),
	(2568, 9, '0-999-051', 10, 48),
	(2569, 9, '0-999-052', 10, 49),
	(2570, 9, '0-999-053', 0, 50),
	(2571, 9, '0-999-054', 0, 51),
	(2572, 9, '0-999-055', 0, 52),
	(2573, 9, '0-999-056', 0, 53),
	(2574, 9, '0-999-057', 0, 54),
	(2575, 9, '0-999-058', 0, 55),
	(2576, 9, '0-999-059', 0, 56),
	(2577, 9, '0-999-060', 0, 57),
	(2578, 9, '0-999-061', 0, 58),
	(2579, 9, '0-999-062', 0, 59),
	(2580, 9, '0-999-063', 0, 60),
	(2581, 9, '0-999-064', 0, 61),
	(2582, 9, '0-999-065', 0, 62),
	(2583, 9, '0-999-066', 0, 63),
	(2584, 9, '0-999-067', 0, 64),
	(2585, 9, '0-999-068', 0, 65),
	(2586, 9, '0-999-069', 0, 66),
	(2587, 9, '0-999-070', 0, 67),
	(2588, 9, '0-999-071', 0, 68),
	(2589, 9, '0-999-072', 0, 69),
	(2590, 9, '0-999-073', 0, 70),
	(2591, 9, '0-999-074', 0, 71),
	(2592, 9, '0-999-075', 0, 72),
	(2593, 9, '0-999-076', 0, 73),
	(2594, 9, '0-999-077', 0, 74),
	(2595, 9, '0-999-078', 0, 75),
	(2596, 9, '0-999-079', 0, 76),
	(2597, 9, '0-999-080', 0, 77),
	(2598, 9, '0-999-081', 0, 78),
	(2599, 9, '0-999-082', 0, 79),
	(2600, 9, '0-999-083', 0, 80),
	(2601, 9, '0-999-084', 0, 81),
	(2602, 9, '0-999-085', 0, 82),
	(2603, 9, '0-999-086', 0, 83),
	(2604, 9, '0-999-087', 0, 84),
	(2605, 9, '0-999-088', 0, 85),
	(2606, 9, '0-999-089', 0, 86),
	(2607, 9, '0-999-090', 0, 87),
	(2608, 9, '0-999-091', 0, 88),
	(2609, 9, '0-999-092', 0, 89),
	(2610, 9, '0-999-093', 0, 90),
	(2611, 9, '0-999-094', 0, 91),
	(2612, 9, '0-999-095', 0, 92),
	(2613, 9, '0-999-096', 0, 93),
	(2614, 9, '0-999-097', 0, 94),
	(2615, 9, '0-999-098', 0, 95),
	(2616, 9, '0-999-099', 0, 96),
	(2617, 9, '0-999-101', 0, 97),
	(2618, 9, '0-999-102', 0, 98),
	(2619, 9, '0-999-103', 0, 99),
	(2620, 9, '0-999-104', 0, 100),
	(2621, 9, '0-999-105', 0, 101),
	(2622, 9, '0-999-106', 0, 102),
	(2623, 9, '0-999-107', 0, 103),
	(2624, 9, '0-999-108', 0, 104),
	(2625, 9, '0-999-109', 0, 105),
	(2626, 9, '0-999-110', 0, 106),
	(2627, 9, '0-999-111', 0, 107),
	(2628, 9, '0-999-112', 0, 108),
	(2629, 9, '0-999-113', 0, 109),
	(2630, 9, '0-999-114', 0, 110),
	(2631, 9, '0-999-115', 0, 111),
	(2632, 9, '0-999-116', 0, 112),
	(2633, 9, '0-999-117', 0, 113),
	(2634, 9, '0-999-118', 0, 114),
	(2635, 9, '0-999-119', 0, 115),
	(2636, 9, '0-999-120', 0, 116),
	(2637, 9, '0-999-121', 0, 117),
	(2638, 9, '0-999-122', 0, 118),
	(2639, 9, '0-999-123', 0, 119),
	(2640, 9, '0-999-124', 0, 120),
	(2641, 9, '0-999-125', 0, 121),
	(2642, 9, '0-999-126', 0, 122),
	(2643, 9, '0-999-127', 0, 123),
	(2644, 9, '0-999-128', 0, 124),
	(2645, 9, '0-999-129', 0, 125),
	(2646, 9, '0-999-130', 0, 126),
	(2647, 9, '0-999-131', 0, 127),
	(2648, 9, '0-999-132', 0, 128),
	(2649, 9, '0-999-133', 0, 129),
	(2650, 9, '0-999-134', 0, 130),
	(2651, 9, '0-999-135', 0, 131),
	(2652, 9, '0-999-136', 0, 132),
	(2653, 9, '0-999-137', 0, 133),
	(2654, 9, '0-999-138', 0, 134),
	(2655, 9, '0-999-139', 0, 135),
	(2656, 9, '0-999-140', 0, 136),
	(2657, 9, '0-999-141', 0, 137),
	(2658, 9, '0-999-142', 0, 138),
	(2659, 9, '0-999-144', 0, 139),
	(2660, 9, '0-999-145', 0, 140),
	(2661, 9, '0-999-146', 0, 141),
	(2662, 9, '0-999-147', 0, 142),
	(2663, 9, '0-999-148', 0, 143),
	(2664, 9, '0-999-149', 0, 144),
	(2665, 9, '0-999-150', 0, 145),
	(2666, 9, '0-999-151', 0, 146),
	(2667, 9, '0-999-152', 0, 147),
	(2668, 9, '0-999-153', 0, 148),
	(2669, 9, '0-999-154', 0, 149),
	(2670, 9, '0-999-155', 0, 150),
	(2671, 9, '0-999-156', 0, 151),
	(2672, 9, '0-999-157', 0, 152),
	(2673, 9, '0-999-158', 0, 153),
	(2674, 9, '0-999-159', 0, 154),
	(2675, 9, '0-999-160', 0, 155),
	(2676, 9, '0-999-161', 0, 156),
	(2677, 9, '0-999-162', 0, 157),
	(2678, 9, '0-999-163', 0, 158),
	(2679, 9, '0-999-164', 0, 159),
	(2680, 9, '0-999-165', 0, 160),
	(2681, 9, '0-999-166', 0, 161),
	(2682, 9, '0-999-167', 0, 162),
	(2683, 9, '0-999-168', 0, 163),
	(2684, 9, '0-999-169', 0, 164),
	(2685, 9, '0-999-170', 0, 165),
	(2686, 9, '0-999-171', 0, 166),
	(2687, 9, '0-999-172', 0, 167),
	(2688, 9, '0-999-173', 0, 168),
	(2689, 9, '0-999-174', 0, 169),
	(2690, 9, '0-999-175', 0, 170),
	(2691, 9, '0-999-176', 0, 171),
	(2692, 9, '0-999-177', 0, 172),
	(2693, 9, '1-999-001', 5, 173),
	(2694, 9, '1-999-002', 0, 174),
	(2695, 9, '1-999-003', 4, 175),
	(2696, 9, '1-999-004', 155, 176),
	(2697, 9, '1-999-005', 165, 177),
	(2698, 9, '1-999-006', 3, 178),
	(2699, 9, '1-999-007', 15, 179),
	(2700, 9, '1-999-008', 3, 180),
	(2701, 9, '1-999-009', 0, 181),
	(2702, 9, '1-999-010', 33, 182),
	(2703, 9, '1-999-011', 17, 183),
	(2704, 9, '1-999-012', 0, 184),
	(2705, 9, '1-999-013', 5, 185),
	(2706, 9, '1-999-014', 8, 186),
	(2707, 9, '1-999-015', 115, 187),
	(2708, 9, '1-999-016', 95, 188),
	(2709, 9, '1-999-017', 95, 189),
	(2710, 9, '1-999-018', 160, 190),
	(2711, 9, '1-999-019', 170, 191),
	(2712, 9, '1-999-020', 120, 192),
	(2713, 9, '1-999-021', 115, 193),
	(2714, 9, '1-999-022', 0, 194),
	(2715, 9, '1-999-023', 20, 195),
	(2716, 9, '1-999-024', 0, 196),
	(2717, 9, '1-999-025', 0, 197),
	(2718, 9, '1-999-026', 0, 198),
	(2719, 9, '1-999-027', 120, 199),
	(2720, 9, '1-999-028', 10, 200),
	(2721, 9, '1-999-029', 41, 201),
	(2722, 9, '1-999-030', 35, 202),
	(2723, 9, '1-999-031', 40, 203),
	(2724, 9, '1-999-032', 120, 204),
	(2725, 9, '1-999-033', 135, 205),
	(2726, 9, '1-999-034', 120, 206),
	(2727, 9, '1-999-035', 130, 207),
	(2728, 9, '1-999-036', 130, 208),
	(2729, 9, '1-999-037', 165, 209),
	(2730, 9, '1-999-038', 120, 210),
	(2731, 9, '1-999-039', 20, 211),
	(2732, 9, '1-999-040', 20, 212),
	(2733, 9, '1-999-041', 3, 213),
	(2734, 9, '1-999-042', 170, 214),
	(2735, 9, '1-999-043', 0, 215),
	(2736, 9, '1-999-044', 107, 216),
	(2737, 9, '1-999-045', 107, 217),
	(2738, 9, '1-999-046', 170, 218),
	(2739, 9, '1-999-047', 160, 219),
	(2740, 9, '1-999-048', 20, 220),
	(2741, 9, '1-999-049', 25, 221),
	(2742, 9, '1-999-050', 20, 222),
	(2743, 9, '1-999-051', 5, 223),
	(2744, 9, '1-999-052', 5, 224),
	(2745, 9, '1-999-053', 25, 225),
	(2746, 9, '1-999-054', 25, 226),
	(2747, 9, '1-999-055', 25, 227),
	(2748, 9, '1-999-056', 25, 228),
	(2749, 9, '1-999-057', 95, 229),
	(2750, 9, '1-999-058', 215, 230),
	(2751, 9, '1-999-059', 13, 231),
	(2752, 9, '1-999-060', 8, 232),
	(2753, 9, '1-999-061', 6, 233),
	(2754, 9, '1-999-062', 7, 234),
	(2755, 9, '1-999-063', 6, 235),
	(2756, 9, '1-999-064', 10, 236),
	(2757, 9, '1-999-065', 9, 237),
	(2758, 9, '1-999-066', 27, 238),
	(2759, 9, '1-999-077', 3, 239),
	(2760, 9, '2-999-000', 0, 240),
	(2761, 9, '2-999-001', 0, 241),
	(2762, 9, '2-999-002', 0, 242),
	(2763, 9, '2-999-003', 20, 243),
	(2764, 9, '2-999-004', 5, 244),
	(2765, 9, '2-999-005', 1, 245),
	(2766, 9, '2-999-006', 21, 246),
	(2767, 9, '2-999-007', 5, 247),
	(2768, 9, '2-999-008', 13, 248),
	(2769, 9, '2-999-009', 4, 249),
	(2770, 9, '2-999-012', 13, 250),
	(2771, 9, '2-999-013', 20, 251),
	(2772, 9, '2-999-014', 3, 252),
	(2773, 9, '2-999-015', 5, 253),
	(2774, 9, '2-999-016', 6, 254),
	(2775, 9, '2-999-017', 2, 255),
	(2776, 9, '2-999-018', 5, 256),
	(2777, 9, '2-999-020', 0, 257),
	(2778, 9, '2-999-021', 7, 258),
	(2779, 9, '2-999-022', 15, 259),
	(2780, 9, '2-999-023', 15, 260),
	(2781, 9, '2-999-024', 30, 261),
	(2782, 9, '2-999-025', 0, 262),
	(2783, 9, '2-999-026', 1, 263),
	(2784, 9, '2-999-027', 5, 264),
	(2785, 9, '2-999-028', 20, 265),
	(2786, 9, '2-999-029', 3, 266),
	(2787, 9, '2-999-030', 5, 267),
	(2788, 9, '2-999-031', 6, 268),
	(2789, 9, '2-999-032', 8, 269),
	(2790, 9, '2-999-033', 5, 270),
	(2791, 9, '2-999-034', 8, 271),
	(2792, 9, '2-999-035', 5, 272),
	(2793, 9, '2-999-036', 10, 273),
	(2794, 9, '2-999-037', 2, 274),
	(2795, 9, '2-999-038', 6, 275),
	(2796, 9, '2-999-039', 3, 276),
	(2797, 9, '2-999-041', 80, 277),
	(2798, 9, '2-999-042', 80, 278),
	(2799, 9, '2-999-043', 0, 279),
	(2800, 9, '2-999-044', 2, 280),
	(2801, 9, '2-999-045', 5, 281),
	(2802, 9, '2-999-046', 1, 282),
	(2803, 9, '2-999-047', 5, 283),
	(2804, 9, '2-999-048', 0, 284),
	(2805, 9, '2-999-049', 6, 285),
	(2806, 9, '2-999-050', 1, 286),
	(2807, 9, '2-999-051', 1, 287),
	(2808, 9, '2-999-052', 8, 288),
	(2809, 9, '2-999-053', 1, 289),
	(2810, 9, '2-999-054', 12, 290),
	(2811, 9, '2-999-055', 4, 291),
	(2812, 9, '2-999-056', 25, 292),
	(2813, 9, '2-999-057', 30, 293),
	(2814, 9, '2-999-058', 0, 294),
	(2815, 9, '2-999-059', 22, 295),
	(2816, 9, '2-999-061', 25, 296),
	(2817, 9, '2-999-062', 15, 297),
	(2818, 9, '2-999-063', 20, 298),
	(2819, 9, '2-999-065', 0, 299),
	(2820, 9, '2-999-066', 0, 300),
	(2821, 9, '2-999-067', 20, 301),
	(2822, 9, '2-999-070', 25, 302),
	(2823, 9, '2-999-071', 5, 303),
	(2824, 9, '2-999-074', 1, 304),
	(2825, 9, '2-999-075', 5, 305),
	(2826, 9, '2-999-076', 12, 306),
	(2827, 9, '2-999-077', 3, 307),
	(2828, 9, '2-999-078', 0, 308),
	(2829, 9, '2-999-079', 7, 309),
	(2830, 9, '2-999-080', 0, 310),
	(2831, 9, '2-999-081', 0, 311),
	(2832, 9, '2-999-082', 0, 312),
	(2833, 9, '2-999-083', 0, 313),
	(2834, 9, '2-999-084', 2, 314),
	(2835, 9, '2-999-085', 0, 315),
	(2836, 10, '0-999-000', 10, 1),
	(2837, 10, '0-999-001', 10, 2),
	(2838, 10, '0-999-002', 40, 3),
	(2839, 10, '0-999-003', 14, 4),
	(2840, 10, '0-999-004', 3, 5),
	(2841, 10, '0-999-005', 2, 6),
	(2842, 10, '0-999-006', 0, 7),
	(2843, 10, '0-999-007', 0, 8),
	(2844, 10, '0-999-008', 0, 9),
	(2845, 10, '0-999-010', 10, 10),
	(2846, 10, '0-999-011', 12, 11),
	(2847, 10, '0-999-013', 3, 12),
	(2848, 10, '0-999-014', 5, 13),
	(2849, 10, '0-999-015', 2, 14),
	(2850, 10, '0-999-016', 2, 15),
	(2851, 10, '0-999-017', 0, 16),
	(2852, 10, '0-999-018', 2, 17),
	(2853, 10, '0-999-019', 0, 18),
	(2854, 10, '0-999-020', 0, 19),
	(2855, 10, '0-999-021', 2, 20),
	(2856, 10, '0-999-022', 2, 21),
	(2857, 10, '0-999-023', 0, 22),
	(2858, 10, '0-999-024', 1, 23),
	(2859, 10, '0-999-025', 1, 24),
	(2860, 10, '0-999-026', 1, 25),
	(2861, 10, '0-999-027', 2, 26),
	(2862, 10, '0-999-028', 0, 27),
	(2863, 10, '0-999-029', 2, 28),
	(2864, 10, '0-999-030', 10, 29),
	(2865, 10, '0-999-031', 20, 30),
	(2866, 10, '0-999-032', 1, 31),
	(2867, 10, '0-999-033', 4, 32),
	(2868, 10, '0-999-034', 3, 33),
	(2869, 10, '0-999-035', 4, 34),
	(2870, 10, '0-999-036', 40, 35),
	(2871, 10, '0-999-037', 0, 36),
	(2872, 10, '0-999-039', 0, 37),
	(2873, 10, '0-999-041', 0, 38),
	(2874, 10, '0-999-042', 0, 39),
	(2875, 10, '0-999-043', 0, 40),
	(2876, 10, '0-999-044', 15, 41),
	(2877, 10, '0-999-045', 7, 42),
	(2878, 10, '0-999-046', 8, 43),
	(2879, 10, '0-999-047', 4, 44),
	(2880, 10, '0-999-048', 8, 45),
	(2881, 10, '0-999-049', 10, 46),
	(2882, 10, '0-999-050', 8, 47),
	(2883, 10, '0-999-051', 8, 48),
	(2884, 10, '0-999-052', 9, 49),
	(2885, 10, '0-999-053', 110, 50),
	(2886, 10, '0-999-054', 60, 51),
	(2887, 10, '0-999-055', 50, 52),
	(2888, 10, '0-999-056', 120, 53),
	(2889, 10, '0-999-057', 125, 54),
	(2890, 10, '0-999-058', 50, 55),
	(2891, 10, '0-999-059', 50, 56),
	(2892, 10, '0-999-060', 110, 57),
	(2893, 10, '0-999-061', 20, 58),
	(2894, 10, '0-999-062', 17, 59),
	(2895, 10, '0-999-063', 16, 60),
	(2896, 10, '0-999-064', 17, 61),
	(2897, 10, '0-999-065', 65, 62),
	(2898, 10, '0-999-066', 30, 63),
	(2899, 10, '0-999-067', 17, 64),
	(2900, 10, '0-999-068', 80, 65),
	(2901, 10, '0-999-069', 80, 66),
	(2902, 10, '0-999-070', 35, 67),
	(2903, 10, '0-999-071', 55, 68),
	(2904, 10, '0-999-072', 55, 69),
	(2905, 10, '0-999-073', 55, 70),
	(2906, 10, '0-999-074', 20, 71),
	(2907, 10, '0-999-075', 7, 72),
	(2908, 10, '0-999-076', 3, 73),
	(2909, 10, '0-999-077', 120, 74),
	(2910, 10, '0-999-078', 6, 75),
	(2911, 10, '0-999-079', 10, 76),
	(2912, 10, '0-999-080', 16, 77),
	(2913, 10, '0-999-081', 0, 78),
	(2914, 10, '0-999-082', 15, 79),
	(2915, 10, '0-999-083', 2, 80),
	(2916, 10, '0-999-084', 16, 81),
	(2917, 10, '0-999-085', 16, 82),
	(2918, 10, '0-999-086', 16, 83),
	(2919, 10, '0-999-087', 70, 84),
	(2920, 10, '0-999-088', 180, 85),
	(2921, 10, '0-999-089', 15, 86),
	(2922, 10, '0-999-090', 4, 87),
	(2923, 10, '0-999-091', 20, 88),
	(2924, 10, '0-999-092', 2, 89),
	(2925, 10, '0-999-093', 3, 90),
	(2926, 10, '0-999-094', 0, 91),
	(2927, 10, '0-999-095', 30, 92),
	(2928, 10, '0-999-096', 10, 93),
	(2929, 10, '0-999-097', 4, 94),
	(2930, 10, '0-999-098', 6, 95),
	(2931, 10, '0-999-099', 0, 96),
	(2932, 10, '0-999-101', 5, 97),
	(2933, 10, '0-999-102', 6, 98),
	(2934, 10, '0-999-103', 0, 99),
	(2935, 10, '0-999-104', 0, 100),
	(2936, 10, '0-999-105', 7, 101),
	(2937, 10, '0-999-106', 6, 102),
	(2938, 10, '0-999-107', 12, 103),
	(2939, 10, '0-999-108', 12, 104),
	(2940, 10, '0-999-109', 0, 105),
	(2941, 10, '0-999-110', 10, 106),
	(2942, 10, '0-999-111', 10, 107),
	(2943, 10, '0-999-112', 10, 108),
	(2944, 10, '0-999-113', 10, 109),
	(2945, 10, '0-999-114', 4, 110),
	(2946, 10, '0-999-115', 8, 111),
	(2947, 10, '0-999-116', 2, 112),
	(2948, 10, '0-999-117', 8, 113),
	(2949, 10, '0-999-118', 3, 114),
	(2950, 10, '0-999-119', 25, 115),
	(2951, 10, '0-999-120', 1, 116),
	(2952, 10, '0-999-121', 10, 117),
	(2953, 10, '0-999-122', 10, 118),
	(2954, 10, '0-999-123', 7, 119),
	(2955, 10, '0-999-124', 8, 120),
	(2956, 10, '0-999-125', 10, 121),
	(2957, 10, '0-999-126', 15, 122),
	(2958, 10, '0-999-127', 30, 123),
	(2959, 10, '0-999-128', 10, 124),
	(2960, 10, '0-999-129', 8, 125),
	(2961, 10, '0-999-130', 8, 126),
	(2962, 10, '0-999-131', 11, 127),
	(2963, 10, '0-999-132', 20, 128),
	(2964, 10, '0-999-133', 20, 129),
	(2965, 10, '0-999-134', 2, 130),
	(2966, 10, '0-999-135', 2, 131),
	(2967, 10, '0-999-136', 10, 132),
	(2968, 10, '0-999-137', 0, 133),
	(2969, 10, '0-999-138', 7, 134),
	(2970, 10, '0-999-139', 40, 135),
	(2971, 10, '0-999-140', 2, 136),
	(2972, 10, '0-999-141', 3, 137),
	(2973, 10, '0-999-142', 3, 138),
	(2974, 10, '0-999-144', 7, 139),
	(2975, 10, '0-999-145', 25, 140),
	(2976, 10, '0-999-146', 25, 141),
	(2977, 10, '0-999-147', 3, 142),
	(2978, 10, '0-999-148', 0, 143),
	(2979, 10, '0-999-149', 5, 144),
	(2980, 10, '0-999-150', 2, 145),
	(2981, 10, '0-999-151', 2, 146),
	(2982, 10, '0-999-152', 6, 147),
	(2983, 10, '0-999-153', 6, 148),
	(2984, 10, '0-999-154', 9, 149),
	(2985, 10, '0-999-155', 8, 150),
	(2986, 10, '0-999-156', 3, 151),
	(2987, 10, '0-999-157', 4, 152),
	(2988, 10, '0-999-158', 30, 153),
	(2989, 10, '0-999-159', 3, 154),
	(2990, 10, '0-999-160', 4, 155),
	(2991, 10, '0-999-161', 8, 156),
	(2992, 10, '0-999-162', 1, 157),
	(2993, 10, '0-999-163', 7, 158),
	(2994, 10, '0-999-164', 0, 159),
	(2995, 10, '0-999-165', 4, 160),
	(2996, 10, '0-999-166', 0, 161),
	(2997, 10, '0-999-167', 0, 162),
	(2998, 10, '0-999-168', 0, 163),
	(2999, 10, '0-999-169', 0, 164),
	(3000, 10, '0-999-170', 0, 165),
	(3001, 10, '0-999-171', 2, 166),
	(3002, 10, '0-999-172', 2, 167),
	(3003, 10, '0-999-173', 0, 168),
	(3004, 10, '0-999-174', 0, 169),
	(3005, 10, '0-999-175', 0, 170),
	(3006, 10, '0-999-176', 0, 171),
	(3007, 10, '0-999-177', 0, 172),
	(3008, 10, '1-999-001', 16, 173),
	(3009, 10, '1-999-002', 3, 174),
	(3010, 10, '1-999-003', 12, 175),
	(3011, 10, '1-999-004', 120, 176),
	(3012, 10, '1-999-005', 120, 177),
	(3013, 10, '1-999-006', 8, 178),
	(3014, 10, '1-999-007', 6, 179),
	(3015, 10, '1-999-008', 0, 180),
	(3016, 10, '1-999-009', 8, 181),
	(3017, 10, '1-999-010', 12, 182),
	(3018, 10, '1-999-011', 8, 183),
	(3019, 10, '1-999-012', 0, 184),
	(3020, 10, '1-999-013', 6, 185),
	(3021, 10, '1-999-014', 9, 186),
	(3022, 10, '1-999-015', 50, 187),
	(3023, 10, '1-999-016', 35, 188),
	(3024, 10, '1-999-017', 25, 189),
	(3025, 10, '1-999-018', 120, 190),
	(3026, 10, '1-999-019', 120, 191),
	(3027, 10, '1-999-020', 40, 192),
	(3028, 10, '1-999-021', 30, 193),
	(3029, 10, '1-999-022', 60, 194),
	(3030, 10, '1-999-023', 60, 195),
	(3031, 10, '1-999-024', 17, 196),
	(3032, 10, '1-999-025', 16, 197),
	(3033, 10, '1-999-026', 17, 198),
	(3034, 10, '1-999-027', 55, 199),
	(3035, 10, '1-999-028', 30, 200),
	(3036, 10, '1-999-029', 17, 201),
	(3037, 10, '1-999-030', 80, 202),
	(3038, 10, '1-999-031', 80, 203),
	(3039, 10, '1-999-032', 35, 204),
	(3040, 10, '1-999-033', 55, 205),
	(3041, 10, '1-999-034', 55, 206),
	(3042, 10, '1-999-035', 35, 207),
	(3043, 10, '1-999-036', 60, 208),
	(3044, 10, '1-999-037', 80, 209),
	(3045, 10, '1-999-038', 35, 210),
	(3046, 10, '1-999-039', 20, 211),
	(3047, 10, '1-999-040', 10, 212),
	(3048, 10, '1-999-041', 3, 213),
	(3049, 10, '1-999-042', 125, 214),
	(3050, 10, '1-999-043', 6, 215),
	(3051, 10, '1-999-044', 40, 216),
	(3052, 10, '1-999-045', 50, 217),
	(3053, 10, '1-999-046', 120, 218),
	(3054, 10, '1-999-047', 120, 219),
	(3055, 10, '1-999-048', 10, 220),
	(3056, 10, '1-999-049', 16, 221),
	(3057, 10, '1-999-050', 0, 222),
	(3058, 10, '1-999-051', 15, 223),
	(3059, 10, '1-999-052', 3, 224),
	(3060, 10, '1-999-053', 16, 225),
	(3061, 10, '1-999-054', 12, 226),
	(3062, 10, '1-999-055', 10, 227),
	(3063, 10, '1-999-056', 70, 228),
	(3064, 10, '1-999-057', 70, 229),
	(3065, 10, '1-999-058', 0, 230),
	(3066, 10, '1-999-059', 10, 231),
	(3067, 10, '1-999-060', 2, 232),
	(3068, 10, '1-999-061', 7, 233),
	(3069, 10, '1-999-062', 2, 234),
	(3070, 10, '1-999-063', 0, 235),
	(3071, 10, '1-999-064', 0, 236),
	(3072, 10, '1-999-065', 0, 237),
	(3073, 10, '1-999-066', 0, 238),
	(3074, 10, '1-999-077', 2, 239),
	(3075, 10, '2-999-000', 0, 240),
	(3076, 10, '2-999-001', 0, 241),
	(3077, 10, '2-999-002', 0, 242),
	(3078, 10, '2-999-003', 15, 243),
	(3079, 10, '2-999-004', 3, 244),
	(3080, 10, '2-999-005', 2, 245),
	(3081, 10, '2-999-006', 0, 246),
	(3082, 10, '2-999-007', 5, 247),
	(3083, 10, '2-999-008', 3, 248),
	(3084, 10, '2-999-009', 3, 249),
	(3085, 10, '2-999-012', 3, 250),
	(3086, 10, '2-999-013', 0, 251),
	(3087, 10, '2-999-014', 4, 252),
	(3088, 10, '2-999-015', 0, 253),
	(3089, 10, '2-999-016', 0, 254),
	(3090, 10, '2-999-017', 0, 255),
	(3091, 10, '2-999-018', 0, 256),
	(3092, 10, '2-999-020', 0, 257),
	(3093, 10, '2-999-021', 5, 258),
	(3094, 10, '2-999-022', 10, 259),
	(3095, 10, '2-999-023', 15, 260),
	(3096, 10, '2-999-024', 0, 261),
	(3097, 10, '2-999-025', 0, 262),
	(3098, 10, '2-999-026', 2, 263),
	(3099, 10, '2-999-027', 5, 264),
	(3100, 10, '2-999-028', 0, 265),
	(3101, 10, '2-999-029', 0, 266),
	(3102, 10, '2-999-030', 5, 267),
	(3103, 10, '2-999-031', 10, 268),
	(3104, 10, '2-999-032', 0, 269),
	(3105, 10, '2-999-033', 0, 270),
	(3106, 10, '2-999-034', 4, 271),
	(3107, 10, '2-999-035', 4, 272),
	(3108, 10, '2-999-036', 5, 273),
	(3109, 10, '2-999-037', 1, 274),
	(3110, 10, '2-999-038', 5, 275),
	(3111, 10, '2-999-039', 5, 276),
	(3112, 10, '2-999-041', 70, 277),
	(3113, 10, '2-999-042', 30, 278),
	(3114, 10, '2-999-043', 0, 279),
	(3115, 10, '2-999-044', 1, 280),
	(3116, 10, '2-999-045', 4, 281),
	(3117, 10, '2-999-046', 1, 282),
	(3118, 10, '2-999-047', 6, 283),
	(3119, 10, '2-999-048', 3, 284),
	(3120, 10, '2-999-049', 10, 285),
	(3121, 10, '2-999-050', 3, 286),
	(3122, 10, '2-999-051', 1, 287),
	(3123, 10, '2-999-052', 7, 288),
	(3124, 10, '2-999-053', 0, 289),
	(3125, 10, '2-999-054', 0, 290),
	(3126, 10, '2-999-055', 1, 291),
	(3127, 10, '2-999-056', 10, 292),
	(3128, 10, '2-999-057', 0, 293),
	(3129, 10, '2-999-058', 8, 294),
	(3130, 10, '2-999-059', 0, 295),
	(3131, 10, '2-999-061', 0, 296),
	(3132, 10, '2-999-062', 0, 297),
	(3133, 10, '2-999-063', 0, 298),
	(3134, 10, '2-999-065', 0, 299),
	(3135, 10, '2-999-066', 0, 300),
	(3136, 10, '2-999-067', 0, 301),
	(3137, 10, '2-999-070', 0, 302),
	(3138, 10, '2-999-071', 34, 303),
	(3139, 10, '2-999-074', 0, 304),
	(3140, 10, '2-999-075', 2, 305),
	(3141, 10, '2-999-076', 6, 306),
	(3142, 10, '2-999-077', 2, 307),
	(3143, 10, '2-999-078', 0, 308),
	(3144, 10, '2-999-079', 0, 309),
	(3145, 10, '2-999-080', 0, 310),
	(3146, 10, '2-999-081', 0, 311),
	(3147, 10, '2-999-082', 0, 312),
	(3148, 10, '2-999-083', 0, 313),
	(3149, 10, '2-999-084', 0, 314),
	(3150, 10, '2-999-085', 0, 315),
	(3151, 11, '0-999-000', 60, 1),
	(3152, 11, '0-999-001', 20, 2),
	(3153, 11, '0-999-002', 65, 3),
	(3154, 11, '0-999-003', 0, 4),
	(3155, 11, '0-999-004', 5, 5),
	(3156, 11, '0-999-005', 17, 6),
	(3157, 11, '0-999-006', 0, 7),
	(3158, 11, '0-999-007', 0, 8),
	(3159, 11, '0-999-008', 5, 9),
	(3160, 11, '0-999-010', 7, 10),
	(3161, 11, '0-999-011', 10, 11),
	(3162, 11, '0-999-013', 2, 12),
	(3163, 11, '0-999-014', 6, 13),
	(3164, 11, '0-999-015', 1, 14),
	(3165, 11, '0-999-016', 2, 15),
	(3166, 11, '0-999-017', 0, 16),
	(3167, 11, '0-999-018', 0, 17),
	(3168, 11, '0-999-019', 0, 18),
	(3169, 11, '0-999-020', 0, 19),
	(3170, 11, '0-999-021', 2, 20),
	(3171, 11, '0-999-022', 3, 21),
	(3172, 11, '0-999-023', 2, 22),
	(3173, 11, '0-999-024', 2, 23),
	(3174, 11, '0-999-025', 1, 24),
	(3175, 11, '0-999-026', 1, 25),
	(3176, 11, '0-999-027', 3, 26),
	(3177, 11, '0-999-028', 2, 27),
	(3178, 11, '0-999-029', 20, 28),
	(3179, 11, '0-999-030', 10, 29),
	(3180, 11, '0-999-031', 20, 30),
	(3181, 11, '0-999-032', 1, 31),
	(3182, 11, '0-999-033', 4, 32),
	(3183, 11, '0-999-034', 4, 33),
	(3184, 11, '0-999-035', 11, 34),
	(3185, 11, '0-999-036', 0, 35),
	(3186, 11, '0-999-037', 0, 36),
	(3187, 11, '0-999-039', 0, 37),
	(3188, 11, '0-999-041', 0, 38),
	(3189, 11, '0-999-042', 0, 39),
	(3190, 11, '0-999-043', 0, 40),
	(3191, 11, '0-999-044', 0, 41),
	(3192, 11, '0-999-045', 0, 42),
	(3193, 11, '0-999-046', 0, 43),
	(3194, 11, '0-999-047', 0, 44),
	(3195, 11, '0-999-048', 0, 45),
	(3196, 11, '0-999-049', 0, 46),
	(3197, 11, '0-999-050', 0, 47),
	(3198, 11, '0-999-051', 0, 48),
	(3199, 11, '0-999-052', 0, 49),
	(3200, 11, '0-999-053', 0, 50),
	(3201, 11, '0-999-054', 0, 51),
	(3202, 11, '0-999-055', 0, 52),
	(3203, 11, '0-999-056', 0, 53),
	(3204, 11, '0-999-057', 0, 54),
	(3205, 11, '0-999-058', 0, 55),
	(3206, 11, '0-999-059', 0, 56),
	(3207, 11, '0-999-060', 0, 57),
	(3208, 11, '0-999-061', 0, 58),
	(3209, 11, '0-999-062', 0, 59),
	(3210, 11, '0-999-063', 0, 60),
	(3211, 11, '0-999-064', 0, 61),
	(3212, 11, '0-999-065', 0, 62),
	(3213, 11, '0-999-066', 0, 63),
	(3214, 11, '0-999-067', 0, 64),
	(3215, 11, '0-999-068', 0, 65),
	(3216, 11, '0-999-069', 0, 66),
	(3217, 11, '0-999-070', 0, 67),
	(3218, 11, '0-999-071', 0, 68),
	(3219, 11, '0-999-072', 0, 69),
	(3220, 11, '0-999-073', 0, 70),
	(3221, 11, '0-999-074', 0, 71),
	(3222, 11, '0-999-075', 0, 72),
	(3223, 11, '0-999-076', 0, 73),
	(3224, 11, '0-999-077', 0, 74),
	(3225, 11, '0-999-078', 0, 75),
	(3226, 11, '0-999-079', 0, 76),
	(3227, 11, '0-999-080', 0, 77),
	(3228, 11, '0-999-081', 0, 78),
	(3229, 11, '0-999-082', 0, 79),
	(3230, 11, '0-999-083', 0, 80),
	(3231, 11, '0-999-084', 0, 81),
	(3232, 11, '0-999-085', 0, 82),
	(3233, 11, '0-999-086', 0, 83),
	(3234, 11, '0-999-087', 0, 84),
	(3235, 11, '0-999-088', 0, 85),
	(3236, 11, '0-999-089', 0, 86),
	(3237, 11, '0-999-090', 0, 87),
	(3238, 11, '0-999-091', 0, 88),
	(3239, 11, '0-999-092', 0, 89),
	(3240, 11, '0-999-093', 0, 90),
	(3241, 11, '0-999-094', 0, 91),
	(3242, 11, '0-999-095', 0, 92),
	(3243, 11, '0-999-096', 0, 93),
	(3244, 11, '0-999-097', 0, 94),
	(3245, 11, '0-999-098', 0, 95),
	(3246, 11, '0-999-099', 0, 96),
	(3247, 11, '0-999-101', 0, 97),
	(3248, 11, '0-999-102', 0, 98),
	(3249, 11, '0-999-103', 0, 99),
	(3250, 11, '0-999-104', 0, 100),
	(3251, 11, '0-999-105', 0, 101),
	(3252, 11, '0-999-106', 0, 102),
	(3253, 11, '0-999-107', 0, 103),
	(3254, 11, '0-999-108', 0, 104),
	(3255, 11, '0-999-109', 0, 105),
	(3256, 11, '0-999-110', 0, 106),
	(3257, 11, '0-999-111', 0, 107),
	(3258, 11, '0-999-112', 0, 108),
	(3259, 11, '0-999-113', 0, 109),
	(3260, 11, '0-999-114', 0, 110),
	(3261, 11, '0-999-115', 0, 111),
	(3262, 11, '0-999-116', 0, 112),
	(3263, 11, '0-999-117', 0, 113),
	(3264, 11, '0-999-118', 0, 114),
	(3265, 11, '0-999-119', 0, 115),
	(3266, 11, '0-999-120', 0, 116),
	(3267, 11, '0-999-121', 0, 117),
	(3268, 11, '0-999-122', 0, 118),
	(3269, 11, '0-999-123', 0, 119),
	(3270, 11, '0-999-124', 0, 120),
	(3271, 11, '0-999-125', 0, 121),
	(3272, 11, '0-999-126', 0, 122),
	(3273, 11, '0-999-127', 0, 123),
	(3274, 11, '0-999-128', 0, 124),
	(3275, 11, '0-999-129', 0, 125),
	(3276, 11, '0-999-130', 0, 126),
	(3277, 11, '0-999-131', 0, 127),
	(3278, 11, '0-999-132', 0, 128),
	(3279, 11, '0-999-133', 0, 129),
	(3280, 11, '0-999-134', 0, 130),
	(3281, 11, '0-999-135', 0, 131),
	(3282, 11, '0-999-136', 0, 132),
	(3283, 11, '0-999-137', 0, 133),
	(3284, 11, '0-999-138', 0, 134),
	(3285, 11, '0-999-139', 0, 135),
	(3286, 11, '0-999-140', 0, 136),
	(3287, 11, '0-999-141', 0, 137),
	(3288, 11, '0-999-142', 0, 138),
	(3289, 11, '0-999-144', 0, 139),
	(3290, 11, '0-999-145', 0, 140),
	(3291, 11, '0-999-146', 0, 141),
	(3292, 11, '0-999-147', 0, 142),
	(3293, 11, '0-999-148', 0, 143),
	(3294, 11, '0-999-149', 0, 144),
	(3295, 11, '0-999-150', 0, 145),
	(3296, 11, '0-999-151', 0, 146),
	(3297, 11, '0-999-152', 0, 147),
	(3298, 11, '0-999-153', 0, 148),
	(3299, 11, '0-999-154', 0, 149),
	(3300, 11, '0-999-155', 0, 150),
	(3301, 11, '0-999-156', 0, 151),
	(3302, 11, '0-999-157', 0, 152),
	(3303, 11, '0-999-158', 0, 153),
	(3304, 11, '0-999-159', 0, 154),
	(3305, 11, '0-999-160', 0, 155),
	(3306, 11, '0-999-161', 0, 156),
	(3307, 11, '0-999-162', 0, 157),
	(3308, 11, '0-999-163', 0, 158),
	(3309, 11, '0-999-164', 0, 159),
	(3310, 11, '0-999-165', 0, 160),
	(3311, 11, '0-999-166', 0, 161),
	(3312, 11, '0-999-167', 0, 162),
	(3313, 11, '0-999-168', 0, 163),
	(3314, 11, '0-999-169', 0, 164),
	(3315, 11, '0-999-170', 0, 165),
	(3316, 11, '0-999-171', 0, 166),
	(3317, 11, '0-999-172', 0, 167),
	(3318, 11, '0-999-173', 0, 168),
	(3319, 11, '0-999-174', 0, 169),
	(3320, 11, '0-999-175', 0, 170),
	(3321, 11, '0-999-176', 0, 171),
	(3322, 11, '0-999-177', 0, 172),
	(3323, 11, '1-999-001', 5, 173),
	(3324, 11, '1-999-002', 0, 174),
	(3325, 11, '1-999-003', 4, 175),
	(3326, 11, '1-999-004', 155, 176),
	(3327, 11, '1-999-005', 165, 177),
	(3328, 11, '1-999-006', 18, 178),
	(3329, 11, '1-999-007', 15, 179),
	(3330, 11, '1-999-008', 3, 180),
	(3331, 11, '1-999-009', 0, 181),
	(3332, 11, '1-999-010', 33, 182),
	(3333, 11, '1-999-011', 17, 183),
	(3334, 11, '1-999-012', 0, 184),
	(3335, 11, '1-999-013', 18, 185),
	(3336, 11, '1-999-014', 19, 186),
	(3337, 11, '1-999-015', 115, 187),
	(3338, 11, '1-999-016', 95, 188),
	(3339, 11, '1-999-017', 95, 189),
	(3340, 11, '1-999-018', 160, 190),
	(3341, 11, '1-999-019', 170, 191),
	(3342, 11, '1-999-020', 120, 192),
	(3343, 11, '1-999-021', 115, 193),
	(3344, 11, '1-999-022', 0, 194),
	(3345, 11, '1-999-023', 20, 195),
	(3346, 11, '1-999-024', 0, 196),
	(3347, 11, '1-999-025', 0, 197),
	(3348, 11, '1-999-026', 0, 198),
	(3349, 11, '1-999-027', 120, 199),
	(3350, 11, '1-999-028', 10, 200),
	(3351, 11, '1-999-029', 41, 201),
	(3352, 11, '1-999-030', 35, 202),
	(3353, 11, '1-999-031', 40, 203),
	(3354, 11, '1-999-032', 120, 204),
	(3355, 11, '1-999-033', 135, 205),
	(3356, 11, '1-999-034', 120, 206),
	(3357, 11, '1-999-035', 130, 207),
	(3358, 11, '1-999-036', 130, 208),
	(3359, 11, '1-999-037', 165, 209),
	(3360, 11, '1-999-038', 120, 210),
	(3361, 11, '1-999-039', 20, 211),
	(3362, 11, '1-999-040', 20, 212),
	(3363, 11, '1-999-041', 3, 213),
	(3364, 11, '1-999-042', 170, 214),
	(3365, 11, '1-999-043', 0, 215),
	(3366, 11, '1-999-044', 107, 216),
	(3367, 11, '1-999-045', 107, 217),
	(3368, 11, '1-999-046', 170, 218),
	(3369, 11, '1-999-047', 160, 219),
	(3370, 11, '1-999-048', 20, 220),
	(3371, 11, '1-999-049', 25, 221),
	(3372, 11, '1-999-050', 20, 222),
	(3373, 11, '1-999-051', 5, 223),
	(3374, 11, '1-999-052', 5, 224),
	(3375, 11, '1-999-053', 25, 225),
	(3376, 11, '1-999-054', 25, 226),
	(3377, 11, '1-999-055', 25, 227),
	(3378, 11, '1-999-056', 25, 228),
	(3379, 11, '1-999-057', 95, 229),
	(3380, 11, '1-999-058', 215, 230),
	(3381, 11, '1-999-059', 13, 231),
	(3382, 11, '1-999-060', 8, 232),
	(3383, 11, '1-999-061', 6, 233),
	(3384, 11, '1-999-062', 7, 234),
	(3385, 11, '1-999-063', 6, 235),
	(3386, 11, '1-999-064', 10, 236),
	(3387, 11, '1-999-065', 9, 237),
	(3388, 11, '1-999-066', 27, 238),
	(3389, 11, '1-999-077', 3, 239),
	(3390, 11, '2-999-000', 0, 240),
	(3391, 11, '2-999-001', 0, 241),
	(3392, 11, '2-999-002', 0, 242),
	(3393, 11, '2-999-003', 20, 243),
	(3394, 11, '2-999-004', 1, 244),
	(3395, 11, '2-999-005', 1, 245),
	(3396, 11, '2-999-006', 0, 246),
	(3397, 11, '2-999-007', 5, 247),
	(3398, 11, '2-999-008', 13, 248),
	(3399, 11, '2-999-009', 4, 249),
	(3400, 11, '2-999-012', 13, 250),
	(3401, 11, '2-999-013', 20, 251),
	(3402, 11, '2-999-014', 3, 252),
	(3403, 11, '2-999-015', 5, 253),
	(3404, 11, '2-999-016', 6, 254),
	(3405, 11, '2-999-017', 2, 255),
	(3406, 11, '2-999-018', 5, 256),
	(3407, 11, '2-999-020', 0, 257),
	(3408, 11, '2-999-021', 7, 258),
	(3409, 11, '2-999-022', 15, 259),
	(3410, 11, '2-999-023', 15, 260),
	(3411, 11, '2-999-024', 30, 261),
	(3412, 11, '2-999-025', 0, 262),
	(3413, 11, '2-999-026', 1, 263),
	(3414, 11, '2-999-027', 5, 264),
	(3415, 11, '2-999-028', 20, 265),
	(3416, 11, '2-999-029', 3, 266),
	(3417, 11, '2-999-030', 4, 267),
	(3418, 11, '2-999-031', 10, 268),
	(3419, 11, '2-999-032', 8, 269),
	(3420, 11, '2-999-033', 7, 270),
	(3421, 11, '2-999-034', 10, 271),
	(3422, 11, '2-999-035', 5, 272),
	(3423, 11, '2-999-036', 10, 273),
	(3424, 11, '2-999-037', 2, 274),
	(3425, 11, '2-999-038', 6, 275),
	(3426, 11, '2-999-039', 3, 276),
	(3427, 11, '2-999-041', 80, 277),
	(3428, 11, '2-999-042', 80, 278),
	(3429, 11, '2-999-043', 0, 279),
	(3430, 11, '2-999-044', 2, 280),
	(3431, 11, '2-999-045', 5, 281),
	(3432, 11, '2-999-046', 1, 282),
	(3433, 11, '2-999-047', 5, 283),
	(3434, 11, '2-999-048', 0, 284),
	(3435, 11, '2-999-049', 6, 285),
	(3436, 11, '2-999-050', 1, 286),
	(3437, 11, '2-999-051', 1, 287),
	(3438, 11, '2-999-052', 8, 288),
	(3439, 11, '2-999-053', 1, 289),
	(3440, 11, '2-999-054', 12, 290),
	(3441, 11, '2-999-055', 4, 291),
	(3442, 11, '2-999-056', 30, 292),
	(3443, 11, '2-999-057', 30, 293),
	(3444, 11, '2-999-058', 0, 294),
	(3445, 11, '2-999-059', 22, 295),
	(3446, 11, '2-999-061', 25, 296),
	(3447, 11, '2-999-062', 15, 297),
	(3448, 11, '2-999-063', 20, 298),
	(3449, 11, '2-999-065', 0, 299),
	(3450, 11, '2-999-066', 0, 300),
	(3451, 11, '2-999-067', 20, 301),
	(3452, 11, '2-999-070', 25, 302),
	(3453, 11, '2-999-071', 5, 303),
	(3454, 11, '2-999-074', 1, 304),
	(3455, 11, '2-999-075', 5, 305),
	(3456, 11, '2-999-076', 12, 306),
	(3457, 11, '2-999-077', 3, 307),
	(3458, 11, '2-999-078', 0, 308),
	(3459, 11, '2-999-079', 7, 309),
	(3460, 11, '2-999-080', 0, 310),
	(3461, 11, '2-999-081', 0, 311),
	(3462, 11, '2-999-082', 0, 312),
	(3463, 11, '2-999-083', 0, 313),
	(3464, 11, '2-999-084', 2, 314),
	(3465, 11, '2-999-085', 0, 315),
	(3466, 12, '0-999-000', 9, 1),
	(3467, 12, '0-999-001', 4, 2),
	(3468, 12, '0-999-002', 30, 3),
	(3469, 12, '0-999-003', 6, 4),
	(3470, 12, '0-999-004', 4, 5),
	(3471, 12, '0-999-005', 2, 6),
	(3472, 12, '0-999-006', 0, 7),
	(3473, 12, '0-999-007', 4, 8),
	(3474, 12, '0-999-008', 0, 9),
	(3475, 12, '0-999-010', 1, 10),
	(3476, 12, '0-999-011', 4, 11),
	(3477, 12, '0-999-013', 3, 12),
	(3478, 12, '0-999-014', 0, 13),
	(3479, 12, '0-999-015', 2, 14),
	(3480, 12, '0-999-016', 2, 15),
	(3481, 12, '0-999-017', 0, 16),
	(3482, 12, '0-999-018', 2, 17),
	(3483, 12, '0-999-019', 0, 18),
	(3484, 12, '0-999-020', 3, 19),
	(3485, 12, '0-999-021', 2, 20),
	(3486, 12, '0-999-022', 2, 21),
	(3487, 12, '0-999-023', 2, 22),
	(3488, 12, '0-999-024', 1, 23),
	(3489, 12, '0-999-025', 1, 24),
	(3490, 12, '0-999-026', 1, 25),
	(3491, 12, '0-999-027', 2, 26),
	(3492, 12, '0-999-028', 2, 27),
	(3493, 12, '0-999-029', 2, 28),
	(3494, 12, '0-999-030', 5, 29),
	(3495, 12, '0-999-031', 20, 30),
	(3496, 12, '0-999-032', 1, 31),
	(3497, 12, '0-999-033', 4, 32),
	(3498, 12, '0-999-034', 3, 33),
	(3499, 12, '0-999-035', 4, 34),
	(3500, 12, '0-999-036', 0, 35),
	(3501, 12, '0-999-037', 0, 36),
	(3502, 12, '0-999-039', 0, 37),
	(3503, 12, '0-999-041', 0, 38),
	(3504, 12, '0-999-042', 0, 39),
	(3505, 12, '0-999-043', 0, 40),
	(3506, 12, '0-999-044', 15, 41),
	(3507, 12, '0-999-045', 0, 42),
	(3508, 12, '0-999-046', 0, 43),
	(3509, 12, '0-999-047', 0, 44),
	(3510, 12, '0-999-048', 0, 45),
	(3511, 12, '0-999-049', 0, 46),
	(3512, 12, '0-999-050', 0, 47),
	(3513, 12, '0-999-051', 0, 48),
	(3514, 12, '0-999-052', 0, 49),
	(3515, 12, '0-999-053', 0, 50),
	(3516, 12, '0-999-054', 0, 51),
	(3517, 12, '0-999-055', 0, 52),
	(3518, 12, '0-999-056', 0, 53),
	(3519, 12, '0-999-057', 0, 54),
	(3520, 12, '0-999-058', 0, 55),
	(3521, 12, '0-999-059', 0, 56),
	(3522, 12, '0-999-060', 0, 57),
	(3523, 12, '0-999-061', 0, 58),
	(3524, 12, '0-999-062', 0, 59),
	(3525, 12, '0-999-063', 0, 60),
	(3526, 12, '0-999-064', 0, 61),
	(3527, 12, '0-999-065', 0, 62),
	(3528, 12, '0-999-066', 0, 63),
	(3529, 12, '0-999-067', 0, 64),
	(3530, 12, '0-999-068', 0, 65),
	(3531, 12, '0-999-069', 0, 66),
	(3532, 12, '0-999-070', 0, 67),
	(3533, 12, '0-999-071', 0, 68),
	(3534, 12, '0-999-072', 0, 69),
	(3535, 12, '0-999-073', 0, 70),
	(3536, 12, '0-999-074', 0, 71),
	(3537, 12, '0-999-075', 0, 72),
	(3538, 12, '0-999-076', 0, 73),
	(3539, 12, '0-999-077', 0, 74),
	(3540, 12, '0-999-078', 0, 75),
	(3541, 12, '0-999-079', 0, 76),
	(3542, 12, '0-999-080', 0, 77),
	(3543, 12, '0-999-081', 0, 78),
	(3544, 12, '0-999-082', 0, 79),
	(3545, 12, '0-999-083', 0, 80),
	(3546, 12, '0-999-084', 0, 81),
	(3547, 12, '0-999-085', 0, 82),
	(3548, 12, '0-999-086', 0, 83),
	(3549, 12, '0-999-087', 0, 84),
	(3550, 12, '0-999-088', 0, 85),
	(3551, 12, '0-999-089', 0, 86),
	(3552, 12, '0-999-090', 0, 87),
	(3553, 12, '0-999-091', 0, 88),
	(3554, 12, '0-999-092', 0, 89),
	(3555, 12, '0-999-093', 0, 90),
	(3556, 12, '0-999-094', 0, 91),
	(3557, 12, '0-999-095', 0, 92),
	(3558, 12, '0-999-096', 0, 93),
	(3559, 12, '0-999-097', 0, 94),
	(3560, 12, '0-999-098', 0, 95),
	(3561, 12, '0-999-099', 0, 96),
	(3562, 12, '0-999-101', 0, 97),
	(3563, 12, '0-999-102', 0, 98),
	(3564, 12, '0-999-103', 0, 99),
	(3565, 12, '0-999-104', 0, 100),
	(3566, 12, '0-999-105', 0, 101),
	(3567, 12, '0-999-106', 0, 102),
	(3568, 12, '0-999-107', 0, 103),
	(3569, 12, '0-999-108', 0, 104),
	(3570, 12, '0-999-109', 0, 105),
	(3571, 12, '0-999-110', 0, 106),
	(3572, 12, '0-999-111', 0, 107),
	(3573, 12, '0-999-112', 0, 108),
	(3574, 12, '0-999-113', 0, 109),
	(3575, 12, '0-999-114', 0, 110),
	(3576, 12, '0-999-115', 0, 111),
	(3577, 12, '0-999-116', 0, 112),
	(3578, 12, '0-999-117', 0, 113),
	(3579, 12, '0-999-118', 0, 114),
	(3580, 12, '0-999-119', 0, 115),
	(3581, 12, '0-999-120', 0, 116),
	(3582, 12, '0-999-121', 0, 117),
	(3583, 12, '0-999-122', 0, 118),
	(3584, 12, '0-999-123', 0, 119),
	(3585, 12, '0-999-124', 0, 120),
	(3586, 12, '0-999-125', 0, 121),
	(3587, 12, '0-999-126', 0, 122),
	(3588, 12, '0-999-127', 0, 123),
	(3589, 12, '0-999-128', 0, 124),
	(3590, 12, '0-999-129', 0, 125),
	(3591, 12, '0-999-130', 0, 126),
	(3592, 12, '0-999-131', 0, 127),
	(3593, 12, '0-999-132', 0, 128),
	(3594, 12, '0-999-133', 0, 129),
	(3595, 12, '0-999-134', 0, 130),
	(3596, 12, '0-999-135', 0, 131),
	(3597, 12, '0-999-136', 0, 132),
	(3598, 12, '0-999-137', 0, 133),
	(3599, 12, '0-999-138', 0, 134),
	(3600, 12, '0-999-139', 0, 135),
	(3601, 12, '0-999-140', 0, 136),
	(3602, 12, '0-999-141', 0, 137),
	(3603, 12, '0-999-142', 0, 138),
	(3604, 12, '0-999-144', 0, 139),
	(3605, 12, '0-999-145', 0, 140),
	(3606, 12, '0-999-146', 0, 141),
	(3607, 12, '0-999-147', 0, 142),
	(3608, 12, '0-999-148', 0, 143),
	(3609, 12, '0-999-149', 0, 144),
	(3610, 12, '0-999-150', 0, 145),
	(3611, 12, '0-999-151', 0, 146),
	(3612, 12, '0-999-152', 0, 147),
	(3613, 12, '0-999-153', 0, 148),
	(3614, 12, '0-999-154', 0, 149),
	(3615, 12, '0-999-155', 0, 150),
	(3616, 12, '0-999-156', 0, 151),
	(3617, 12, '0-999-157', 0, 152),
	(3618, 12, '0-999-158', 0, 153),
	(3619, 12, '0-999-159', 0, 154),
	(3620, 12, '0-999-160', 0, 155),
	(3621, 12, '0-999-161', 0, 156),
	(3622, 12, '0-999-162', 0, 157),
	(3623, 12, '0-999-163', 0, 158),
	(3624, 12, '0-999-164', 0, 159),
	(3625, 12, '0-999-165', 0, 160),
	(3626, 12, '0-999-166', 0, 161),
	(3627, 12, '0-999-167', 0, 162),
	(3628, 12, '0-999-168', 0, 163),
	(3629, 12, '0-999-169', 0, 164),
	(3630, 12, '0-999-170', 0, 165),
	(3631, 12, '0-999-171', 0, 166),
	(3632, 12, '0-999-172', 0, 167),
	(3633, 12, '0-999-173', 0, 168),
	(3634, 12, '0-999-174', 0, 169),
	(3635, 12, '0-999-175', 0, 170),
	(3636, 12, '0-999-176', 0, 171),
	(3637, 12, '0-999-177', 0, 172),
	(3638, 12, '1-999-001', 8, 173),
	(3639, 12, '1-999-002', 1, 174),
	(3640, 12, '1-999-003', 3, 175),
	(3641, 12, '1-999-004', 86, 176),
	(3642, 12, '1-999-005', 90, 177),
	(3643, 12, '1-999-006', 5, 178),
	(3644, 12, '1-999-007', 5, 179),
	(3645, 12, '1-999-008', 3, 180),
	(3646, 12, '1-999-009', 7, 181),
	(3647, 12, '1-999-010', 6, 182),
	(3648, 12, '1-999-011', 4, 183),
	(3649, 12, '1-999-012', 5, 184),
	(3650, 12, '1-999-013', 2, 185),
	(3651, 12, '1-999-014', 3, 186),
	(3652, 12, '1-999-015', 60, 187),
	(3653, 12, '1-999-016', 40, 188),
	(3654, 12, '1-999-017', 15, 189),
	(3655, 12, '1-999-018', 97, 190),
	(3656, 12, '1-999-019', 100, 191),
	(3657, 12, '1-999-020', 54, 192),
	(3658, 12, '1-999-021', 26, 193),
	(3659, 12, '1-999-022', 72, 194),
	(3660, 12, '1-999-023', 8, 195),
	(3661, 12, '1-999-024', 4, 196),
	(3662, 12, '1-999-025', 4, 197),
	(3663, 12, '1-999-026', 4, 198),
	(3664, 12, '1-999-027', 66, 199),
	(3665, 12, '1-999-028', 30, 200),
	(3666, 12, '1-999-029', 30, 201),
	(3667, 12, '1-999-030', 14, 202),
	(3668, 12, '1-999-031', 18, 203),
	(3669, 12, '1-999-032', 26, 204),
	(3670, 12, '1-999-033', 66, 205),
	(3671, 12, '1-999-034', 54, 206),
	(3672, 12, '1-999-035', 50, 207),
	(3673, 12, '1-999-036', 70, 208),
	(3674, 12, '1-999-037', 78, 209),
	(3675, 12, '1-999-038', 36, 210),
	(3676, 12, '1-999-039', 15, 211),
	(3677, 12, '1-999-040', 7, 212),
	(3678, 12, '1-999-041', 3, 213),
	(3679, 12, '1-999-042', 97, 214),
	(3680, 12, '1-999-043', 2, 215),
	(3681, 12, '1-999-044', 29, 216),
	(3682, 12, '1-999-045', 56, 217),
	(3683, 12, '1-999-046', 90, 218),
	(3684, 12, '1-999-047', 97, 219),
	(3685, 12, '1-999-048', 8, 220),
	(3686, 12, '1-999-049', 8, 221),
	(3687, 12, '1-999-050', 6, 222),
	(3688, 12, '1-999-051', 7, 223),
	(3689, 12, '1-999-052', 4, 224),
	(3690, 12, '1-999-053', 7, 225),
	(3691, 12, '1-999-054', 7, 226),
	(3692, 12, '1-999-055', 8, 227),
	(3693, 12, '1-999-056', 8, 228),
	(3694, 12, '1-999-057', 25, 229),
	(3695, 12, '1-999-058', 174, 230),
	(3696, 12, '1-999-059', 7, 231),
	(3697, 12, '1-999-060', 5, 232),
	(3698, 12, '1-999-061', 5, 233),
	(3699, 12, '1-999-062', 2, 234),
	(3700, 12, '1-999-063', 3, 235),
	(3701, 12, '1-999-064', 0, 236),
	(3702, 12, '1-999-065', 0, 237),
	(3703, 12, '1-999-066', 0, 238),
	(3704, 12, '1-999-077', 0, 239),
	(3705, 12, '2-999-000', 3, 240),
	(3706, 12, '2-999-001', 3, 241),
	(3707, 12, '2-999-002', 3, 242),
	(3708, 12, '2-999-003', 22, 243),
	(3709, 12, '2-999-004', 2, 244),
	(3710, 12, '2-999-005', 2, 245),
	(3711, 12, '2-999-006', 27, 246),
	(3712, 12, '2-999-007', 3, 247),
	(3713, 12, '2-999-008', 4, 248),
	(3714, 12, '2-999-009', 2, 249),
	(3715, 12, '2-999-012', 5, 250),
	(3716, 12, '2-999-013', 10, 251),
	(3717, 12, '2-999-014', 5, 252),
	(3718, 12, '2-999-015', 4, 253),
	(3719, 12, '2-999-016', 7, 254),
	(3720, 12, '2-999-017', 6, 255),
	(3721, 12, '2-999-018', 5, 256),
	(3722, 12, '2-999-020', 4, 257),
	(3723, 12, '2-999-021', 3, 258),
	(3724, 12, '2-999-022', 10, 259),
	(3725, 12, '2-999-023', 20, 260),
	(3726, 12, '2-999-024', 20, 261),
	(3727, 12, '2-999-025', 30, 262),
	(3728, 12, '2-999-026', 1, 263),
	(3729, 12, '2-999-027', 1, 264),
	(3730, 12, '2-999-028', 5, 265),
	(3731, 12, '2-999-029', 5, 266),
	(3732, 12, '2-999-030', 5, 267),
	(3733, 12, '2-999-031', 10, 268),
	(3734, 12, '2-999-032', 6, 269),
	(3735, 12, '2-999-033', 6, 270),
	(3736, 12, '2-999-034', 6, 271),
	(3737, 12, '2-999-035', 6, 272),
	(3738, 12, '2-999-036', 5, 273),
	(3739, 12, '2-999-037', 1, 274),
	(3740, 12, '2-999-038', 5, 275),
	(3741, 12, '2-999-039', 2, 276),
	(3742, 12, '2-999-041', 100, 277),
	(3743, 12, '2-999-042', 6, 278),
	(3744, 12, '2-999-043', 2, 279),
	(3745, 12, '2-999-044', 2, 280),
	(3746, 12, '2-999-045', 2, 281),
	(3747, 12, '2-999-046', 1, 282),
	(3748, 12, '2-999-047', 6, 283),
	(3749, 12, '2-999-048', 4, 284),
	(3750, 12, '2-999-049', 3, 285),
	(3751, 12, '2-999-050', 1, 286),
	(3752, 12, '2-999-051', 3, 287),
	(3753, 12, '2-999-052', 3, 288),
	(3754, 12, '2-999-053', 3, 289),
	(3755, 12, '2-999-054', 1, 290),
	(3756, 12, '2-999-055', 1, 291),
	(3757, 12, '2-999-056', 0, 292),
	(3758, 12, '2-999-057', 0, 293),
	(3759, 12, '2-999-058', 0, 294),
	(3760, 12, '2-999-059', 0, 295),
	(3761, 12, '2-999-061', 0, 296),
	(3762, 12, '2-999-062', 0, 297),
	(3763, 12, '2-999-063', 0, 298),
	(3764, 12, '2-999-065', 0, 299),
	(3765, 12, '2-999-066', 0, 300),
	(3766, 12, '2-999-067', 0, 301),
	(3767, 12, '2-999-070', 0, 302),
	(3768, 12, '2-999-071', 0, 303),
	(3769, 12, '2-999-074', 0, 304),
	(3770, 12, '2-999-075', 0, 305),
	(3771, 12, '2-999-076', 0, 306),
	(3772, 12, '2-999-077', 0, 307),
	(3773, 12, '2-999-078', 0, 308),
	(3774, 12, '2-999-079', 0, 309),
	(3775, 12, '2-999-080', 0, 310),
	(3776, 12, '2-999-081', 0, 311),
	(3777, 12, '2-999-082', 0, 312),
	(3778, 12, '2-999-083', 3, 313),
	(3779, 12, '2-999-084', 0, 314),
	(3780, 12, '2-999-085', 0, 315),
	(3781, 13, '0-999-000', 9, 1),
	(3782, 13, '0-999-001', 4, 2),
	(3783, 13, '0-999-002', 30, 3),
	(3784, 13, '0-999-003', 6, 4),
	(3785, 13, '0-999-004', 4, 5),
	(3786, 13, '0-999-005', 2, 6),
	(3787, 13, '0-999-006', 0, 7),
	(3788, 13, '0-999-007', 4, 8),
	(3789, 13, '0-999-008', 0, 9),
	(3790, 13, '0-999-010', 1, 10),
	(3791, 13, '0-999-011', 4, 11),
	(3792, 13, '0-999-013', 3, 12),
	(3793, 13, '0-999-014', 0, 13),
	(3794, 13, '0-999-015', 2, 14),
	(3795, 13, '0-999-016', 2, 15),
	(3796, 13, '0-999-017', 0, 16),
	(3797, 13, '0-999-018', 2, 17),
	(3798, 13, '0-999-019', 0, 18),
	(3799, 13, '0-999-020', 3, 19),
	(3800, 13, '0-999-021', 2, 20),
	(3801, 13, '0-999-022', 2, 21),
	(3802, 13, '0-999-023', 2, 22),
	(3803, 13, '0-999-024', 1, 23),
	(3804, 13, '0-999-025', 1, 24),
	(3805, 13, '0-999-026', 1, 25),
	(3806, 13, '0-999-027', 2, 26),
	(3807, 13, '0-999-028', 2, 27),
	(3808, 13, '0-999-029', 2, 28),
	(3809, 13, '0-999-030', 5, 29),
	(3810, 13, '0-999-031', 20, 30),
	(3811, 13, '0-999-032', 1, 31),
	(3812, 13, '0-999-033', 4, 32),
	(3813, 13, '0-999-034', 3, 33),
	(3814, 13, '0-999-035', 4, 34),
	(3815, 13, '0-999-036', 0, 35),
	(3816, 13, '0-999-037', 0, 36),
	(3817, 13, '0-999-039', 0, 37),
	(3818, 13, '0-999-041', 0, 38),
	(3819, 13, '0-999-042', 0, 39),
	(3820, 13, '0-999-043', 0, 40),
	(3821, 13, '0-999-044', 15, 41),
	(3822, 13, '0-999-045', 0, 42),
	(3823, 13, '0-999-046', 0, 43),
	(3824, 13, '0-999-047', 0, 44),
	(3825, 13, '0-999-048', 0, 45),
	(3826, 13, '0-999-049', 0, 46),
	(3827, 13, '0-999-050', 0, 47),
	(3828, 13, '0-999-051', 0, 48),
	(3829, 13, '0-999-052', 0, 49),
	(3830, 13, '0-999-053', 0, 50),
	(3831, 13, '0-999-054', 0, 51),
	(3832, 13, '0-999-055', 0, 52),
	(3833, 13, '0-999-056', 0, 53),
	(3834, 13, '0-999-057', 0, 54),
	(3835, 13, '0-999-058', 0, 55),
	(3836, 13, '0-999-059', 0, 56),
	(3837, 13, '0-999-060', 0, 57),
	(3838, 13, '0-999-061', 0, 58),
	(3839, 13, '0-999-062', 0, 59),
	(3840, 13, '0-999-063', 0, 60),
	(3841, 13, '0-999-064', 0, 61),
	(3842, 13, '0-999-065', 0, 62),
	(3843, 13, '0-999-066', 0, 63),
	(3844, 13, '0-999-067', 0, 64),
	(3845, 13, '0-999-068', 0, 65),
	(3846, 13, '0-999-069', 0, 66),
	(3847, 13, '0-999-070', 0, 67),
	(3848, 13, '0-999-071', 0, 68),
	(3849, 13, '0-999-072', 0, 69),
	(3850, 13, '0-999-073', 0, 70),
	(3851, 13, '0-999-074', 0, 71),
	(3852, 13, '0-999-075', 0, 72),
	(3853, 13, '0-999-076', 0, 73),
	(3854, 13, '0-999-077', 0, 74),
	(3855, 13, '0-999-078', 0, 75),
	(3856, 13, '0-999-079', 0, 76),
	(3857, 13, '0-999-080', 0, 77),
	(3858, 13, '0-999-081', 0, 78),
	(3859, 13, '0-999-082', 0, 79),
	(3860, 13, '0-999-083', 0, 80),
	(3861, 13, '0-999-084', 0, 81),
	(3862, 13, '0-999-085', 0, 82),
	(3863, 13, '0-999-086', 0, 83),
	(3864, 13, '0-999-087', 0, 84),
	(3865, 13, '0-999-088', 0, 85),
	(3866, 13, '0-999-089', 0, 86),
	(3867, 13, '0-999-090', 0, 87),
	(3868, 13, '0-999-091', 0, 88),
	(3869, 13, '0-999-092', 0, 89),
	(3870, 13, '0-999-093', 0, 90),
	(3871, 13, '0-999-094', 0, 91),
	(3872, 13, '0-999-095', 0, 92),
	(3873, 13, '0-999-096', 0, 93),
	(3874, 13, '0-999-097', 0, 94),
	(3875, 13, '0-999-098', 0, 95),
	(3876, 13, '0-999-099', 0, 96),
	(3877, 13, '0-999-101', 0, 97),
	(3878, 13, '0-999-102', 0, 98),
	(3879, 13, '0-999-103', 0, 99),
	(3880, 13, '0-999-104', 0, 100),
	(3881, 13, '0-999-105', 0, 101),
	(3882, 13, '0-999-106', 0, 102),
	(3883, 13, '0-999-107', 0, 103),
	(3884, 13, '0-999-108', 0, 104),
	(3885, 13, '0-999-109', 0, 105),
	(3886, 13, '0-999-110', 0, 106),
	(3887, 13, '0-999-111', 0, 107),
	(3888, 13, '0-999-112', 0, 108),
	(3889, 13, '0-999-113', 0, 109),
	(3890, 13, '0-999-114', 0, 110),
	(3891, 13, '0-999-115', 0, 111),
	(3892, 13, '0-999-116', 0, 112),
	(3893, 13, '0-999-117', 0, 113),
	(3894, 13, '0-999-118', 0, 114),
	(3895, 13, '0-999-119', 0, 115),
	(3896, 13, '0-999-120', 0, 116),
	(3897, 13, '0-999-121', 0, 117),
	(3898, 13, '0-999-122', 0, 118),
	(3899, 13, '0-999-123', 0, 119),
	(3900, 13, '0-999-124', 0, 120),
	(3901, 13, '0-999-125', 0, 121),
	(3902, 13, '0-999-126', 0, 122),
	(3903, 13, '0-999-127', 0, 123),
	(3904, 13, '0-999-128', 0, 124),
	(3905, 13, '0-999-129', 0, 125),
	(3906, 13, '0-999-130', 0, 126),
	(3907, 13, '0-999-131', 0, 127),
	(3908, 13, '0-999-132', 0, 128),
	(3909, 13, '0-999-133', 0, 129),
	(3910, 13, '0-999-134', 0, 130),
	(3911, 13, '0-999-135', 0, 131),
	(3912, 13, '0-999-136', 0, 132),
	(3913, 13, '0-999-137', 0, 133),
	(3914, 13, '0-999-138', 0, 134),
	(3915, 13, '0-999-139', 0, 135),
	(3916, 13, '0-999-140', 0, 136),
	(3917, 13, '0-999-141', 0, 137),
	(3918, 13, '0-999-142', 0, 138),
	(3919, 13, '0-999-144', 0, 139),
	(3920, 13, '0-999-145', 0, 140),
	(3921, 13, '0-999-146', 0, 141),
	(3922, 13, '0-999-147', 0, 142),
	(3923, 13, '0-999-148', 0, 143),
	(3924, 13, '0-999-149', 0, 144),
	(3925, 13, '0-999-150', 0, 145),
	(3926, 13, '0-999-151', 0, 146),
	(3927, 13, '0-999-152', 0, 147),
	(3928, 13, '0-999-153', 0, 148),
	(3929, 13, '0-999-154', 0, 149),
	(3930, 13, '0-999-155', 0, 150),
	(3931, 13, '0-999-156', 0, 151),
	(3932, 13, '0-999-157', 0, 152),
	(3933, 13, '0-999-158', 0, 153),
	(3934, 13, '0-999-159', 0, 154),
	(3935, 13, '0-999-160', 0, 155),
	(3936, 13, '0-999-161', 0, 156),
	(3937, 13, '0-999-162', 0, 157),
	(3938, 13, '0-999-163', 0, 158),
	(3939, 13, '0-999-164', 0, 159),
	(3940, 13, '0-999-165', 0, 160),
	(3941, 13, '0-999-166', 0, 161),
	(3942, 13, '0-999-167', 0, 162),
	(3943, 13, '0-999-168', 0, 163),
	(3944, 13, '0-999-169', 0, 164),
	(3945, 13, '0-999-170', 0, 165),
	(3946, 13, '0-999-171', 0, 166),
	(3947, 13, '0-999-172', 0, 167),
	(3948, 13, '0-999-173', 0, 168),
	(3949, 13, '0-999-174', 0, 169),
	(3950, 13, '0-999-175', 0, 170),
	(3951, 13, '0-999-176', 0, 171),
	(3952, 13, '0-999-177', 0, 172),
	(3953, 13, '1-999-001', 8, 173),
	(3954, 13, '1-999-002', 1, 174),
	(3955, 13, '1-999-003', 3, 175),
	(3956, 13, '1-999-004', 86, 176),
	(3957, 13, '1-999-005', 90, 177),
	(3958, 13, '1-999-006', 5, 178),
	(3959, 13, '1-999-007', 5, 179),
	(3960, 13, '1-999-008', 3, 180),
	(3961, 13, '1-999-009', 7, 181),
	(3962, 13, '1-999-010', 6, 182),
	(3963, 13, '1-999-011', 4, 183),
	(3964, 13, '1-999-012', 5, 184),
	(3965, 13, '1-999-013', 2, 185),
	(3966, 13, '1-999-014', 3, 186),
	(3967, 13, '1-999-015', 60, 187),
	(3968, 13, '1-999-016', 40, 188),
	(3969, 13, '1-999-017', 15, 189),
	(3970, 13, '1-999-018', 97, 190),
	(3971, 13, '1-999-019', 100, 191),
	(3972, 13, '1-999-020', 54, 192),
	(3973, 13, '1-999-021', 26, 193),
	(3974, 13, '1-999-022', 72, 194),
	(3975, 13, '1-999-023', 8, 195),
	(3976, 13, '1-999-024', 4, 196),
	(3977, 13, '1-999-025', 4, 197),
	(3978, 13, '1-999-026', 4, 198),
	(3979, 13, '1-999-027', 66, 199),
	(3980, 13, '1-999-028', 30, 200),
	(3981, 13, '1-999-029', 30, 201),
	(3982, 13, '1-999-030', 14, 202),
	(3983, 13, '1-999-031', 18, 203),
	(3984, 13, '1-999-032', 26, 204),
	(3985, 13, '1-999-033', 66, 205),
	(3986, 13, '1-999-034', 54, 206),
	(3987, 13, '1-999-035', 50, 207),
	(3988, 13, '1-999-036', 70, 208),
	(3989, 13, '1-999-037', 78, 209),
	(3990, 13, '1-999-038', 36, 210),
	(3991, 13, '1-999-039', 15, 211),
	(3992, 13, '1-999-040', 7, 212),
	(3993, 13, '1-999-041', 3, 213),
	(3994, 13, '1-999-042', 97, 214),
	(3995, 13, '1-999-043', 2, 215),
	(3996, 13, '1-999-044', 29, 216),
	(3997, 13, '1-999-045', 56, 217),
	(3998, 13, '1-999-046', 90, 218),
	(3999, 13, '1-999-047', 97, 219),
	(4000, 13, '1-999-048', 8, 220),
	(4001, 13, '1-999-049', 8, 221),
	(4002, 13, '1-999-050', 6, 222),
	(4003, 13, '1-999-051', 7, 223),
	(4004, 13, '1-999-052', 5, 224),
	(4005, 13, '1-999-053', 7, 225),
	(4006, 13, '1-999-054', 7, 226),
	(4007, 13, '1-999-055', 8, 227),
	(4008, 13, '1-999-056', 8, 228),
	(4009, 13, '1-999-057', 25, 229),
	(4010, 13, '1-999-058', 174, 230),
	(4011, 13, '1-999-059', 7, 231),
	(4012, 13, '1-999-060', 5, 232),
	(4013, 13, '1-999-061', 5, 233),
	(4014, 13, '1-999-062', 2, 234),
	(4015, 13, '1-999-063', 3, 235),
	(4016, 13, '1-999-064', 0, 236),
	(4017, 13, '1-999-065', 0, 237),
	(4018, 13, '1-999-066', 0, 238),
	(4019, 13, '1-999-077', 0, 239),
	(4020, 13, '2-999-000', 3, 240),
	(4021, 13, '2-999-001', 3, 241),
	(4022, 13, '2-999-002', 3, 242),
	(4023, 13, '2-999-003', 22, 243),
	(4024, 13, '2-999-004', 2, 244),
	(4025, 13, '2-999-005', 2, 245),
	(4026, 13, '2-999-006', 27, 246),
	(4027, 13, '2-999-007', 3, 247),
	(4028, 13, '2-999-008', 4, 248),
	(4029, 13, '2-999-009', 2, 249),
	(4030, 13, '2-999-012', 5, 250),
	(4031, 13, '2-999-013', 10, 251),
	(4032, 13, '2-999-014', 5, 252),
	(4033, 13, '2-999-015', 4, 253),
	(4034, 13, '2-999-016', 7, 254),
	(4035, 13, '2-999-017', 6, 255),
	(4036, 13, '2-999-018', 5, 256),
	(4037, 13, '2-999-020', 4, 257),
	(4038, 13, '2-999-021', 3, 258),
	(4039, 13, '2-999-022', 10, 259),
	(4040, 13, '2-999-023', 20, 260),
	(4041, 13, '2-999-024', 20, 261),
	(4042, 13, '2-999-025', 30, 262),
	(4043, 13, '2-999-026', 1, 263),
	(4044, 13, '2-999-027', 1, 264),
	(4045, 13, '2-999-028', 5, 265),
	(4046, 13, '2-999-029', 5, 266),
	(4047, 13, '2-999-030', 5, 267),
	(4048, 13, '2-999-031', 10, 268),
	(4049, 13, '2-999-032', 6, 269),
	(4050, 13, '2-999-033', 6, 270),
	(4051, 13, '2-999-034', 6, 271),
	(4052, 13, '2-999-035', 6, 272),
	(4053, 13, '2-999-036', 5, 273),
	(4054, 13, '2-999-037', 1, 274),
	(4055, 13, '2-999-038', 5, 275),
	(4056, 13, '2-999-039', 2, 276),
	(4057, 13, '2-999-041', 100, 277),
	(4058, 13, '2-999-042', 6, 278),
	(4059, 13, '2-999-043', 2, 279),
	(4060, 13, '2-999-044', 2, 280),
	(4061, 13, '2-999-045', 2, 281),
	(4062, 13, '2-999-046', 1, 282),
	(4063, 13, '2-999-047', 6, 283),
	(4064, 13, '2-999-048', 4, 284),
	(4065, 13, '2-999-049', 3, 285),
	(4066, 13, '2-999-050', 1, 286),
	(4067, 13, '2-999-051', 3, 287),
	(4068, 13, '2-999-052', 3, 288),
	(4069, 13, '2-999-053', 3, 289),
	(4070, 13, '2-999-054', 1, 290),
	(4071, 13, '2-999-055', 1, 291),
	(4072, 13, '2-999-056', 0, 292),
	(4073, 13, '2-999-057', 0, 293),
	(4074, 13, '2-999-058', 0, 294),
	(4075, 13, '2-999-059', 0, 295),
	(4076, 13, '2-999-061', 0, 296),
	(4077, 13, '2-999-062', 0, 297),
	(4078, 13, '2-999-063', 0, 298),
	(4079, 13, '2-999-065', 0, 299),
	(4080, 13, '2-999-066', 0, 300),
	(4081, 13, '2-999-067', 0, 301),
	(4082, 13, '2-999-070', 0, 302),
	(4083, 13, '2-999-071', 0, 303),
	(4084, 13, '2-999-074', 0, 304),
	(4085, 13, '2-999-075', 0, 305),
	(4086, 13, '2-999-076', 0, 306),
	(4087, 13, '2-999-077', 0, 307),
	(4088, 13, '2-999-078', 0, 308),
	(4089, 13, '2-999-079', 0, 309),
	(4090, 13, '2-999-080', 0, 310),
	(4091, 13, '2-999-081', 0, 311),
	(4092, 13, '2-999-082', 0, 312),
	(4093, 13, '2-999-083', 3, 313),
	(4094, 13, '2-999-084', 0, 314),
	(4095, 13, '2-999-085', 0, 315),
	(4096, 14, '0-999-000', 15, 1),
	(4097, 14, '0-999-001', 6, 2),
	(4098, 14, '0-999-002', 45, 3),
	(4099, 14, '0-999-003', 8, 4),
	(4100, 14, '0-999-004', 5, 5),
	(4101, 14, '0-999-005', 6, 6),
	(4102, 14, '0-999-006', 0, 7),
	(4103, 14, '0-999-007', 6, 8),
	(4104, 14, '0-999-008', 0, 9),
	(4105, 14, '0-999-010', 2, 10),
	(4106, 14, '0-999-011', 5, 11),
	(4107, 14, '0-999-013', 3, 12),
	(4108, 14, '0-999-014', 6, 13),
	(4109, 14, '0-999-015', 2, 14),
	(4110, 14, '0-999-016', 3, 15),
	(4111, 14, '0-999-017', 0, 16),
	(4112, 14, '0-999-018', 2, 17),
	(4113, 14, '0-999-019', 0, 18),
	(4114, 14, '0-999-020', 5, 19),
	(4115, 14, '0-999-021', 2, 20),
	(4116, 14, '0-999-022', 2, 21),
	(4117, 14, '0-999-023', 2, 22),
	(4118, 14, '0-999-024', 1, 23),
	(4119, 14, '0-999-025', 1, 24),
	(4120, 14, '0-999-026', 1, 25),
	(4121, 14, '0-999-027', 2, 26),
	(4122, 14, '0-999-028', 2, 27),
	(4123, 14, '0-999-029', 1, 28),
	(4124, 14, '0-999-030', 5, 29),
	(4125, 14, '0-999-031', 20, 30),
	(4126, 14, '0-999-032', 1, 31),
	(4127, 14, '0-999-033', 4, 32),
	(4128, 14, '0-999-034', 3, 33),
	(4129, 14, '0-999-035', 4, 34),
	(4130, 14, '0-999-036', 0, 35),
	(4131, 14, '0-999-037', 0, 36),
	(4132, 14, '0-999-039', 0, 37),
	(4133, 14, '0-999-041', 0, 38),
	(4134, 14, '0-999-042', 0, 39),
	(4135, 14, '0-999-043', 0, 40),
	(4136, 14, '0-999-044', 15, 41),
	(4137, 14, '0-999-045', 0, 42),
	(4138, 14, '0-999-046', 0, 43),
	(4139, 14, '0-999-047', 0, 44),
	(4140, 14, '0-999-048', 0, 45),
	(4141, 14, '0-999-049', 0, 46),
	(4142, 14, '0-999-050', 0, 47),
	(4143, 14, '0-999-051', 0, 48),
	(4144, 14, '0-999-052', 0, 49),
	(4145, 14, '0-999-053', 0, 50),
	(4146, 14, '0-999-054', 0, 51),
	(4147, 14, '0-999-055', 0, 52),
	(4148, 14, '0-999-056', 0, 53),
	(4149, 14, '0-999-057', 0, 54),
	(4150, 14, '0-999-058', 0, 55),
	(4151, 14, '0-999-059', 0, 56),
	(4152, 14, '0-999-060', 0, 57),
	(4153, 14, '0-999-061', 0, 58),
	(4154, 14, '0-999-062', 0, 59),
	(4155, 14, '0-999-063', 0, 60),
	(4156, 14, '0-999-064', 0, 61),
	(4157, 14, '0-999-065', 0, 62),
	(4158, 14, '0-999-066', 0, 63),
	(4159, 14, '0-999-067', 0, 64),
	(4160, 14, '0-999-068', 0, 65),
	(4161, 14, '0-999-069', 0, 66),
	(4162, 14, '0-999-070', 0, 67),
	(4163, 14, '0-999-071', 0, 68),
	(4164, 14, '0-999-072', 0, 69),
	(4165, 14, '0-999-073', 0, 70),
	(4166, 14, '0-999-074', 0, 71),
	(4167, 14, '0-999-075', 0, 72),
	(4168, 14, '0-999-076', 0, 73),
	(4169, 14, '0-999-077', 0, 74),
	(4170, 14, '0-999-078', 0, 75),
	(4171, 14, '0-999-079', 0, 76),
	(4172, 14, '0-999-080', 0, 77),
	(4173, 14, '0-999-081', 0, 78),
	(4174, 14, '0-999-082', 0, 79),
	(4175, 14, '0-999-083', 0, 80),
	(4176, 14, '0-999-084', 0, 81),
	(4177, 14, '0-999-085', 0, 82),
	(4178, 14, '0-999-086', 0, 83),
	(4179, 14, '0-999-087', 0, 84),
	(4180, 14, '0-999-088', 0, 85),
	(4181, 14, '0-999-089', 0, 86),
	(4182, 14, '0-999-090', 0, 87),
	(4183, 14, '0-999-091', 0, 88),
	(4184, 14, '0-999-092', 0, 89),
	(4185, 14, '0-999-093', 0, 90),
	(4186, 14, '0-999-094', 0, 91),
	(4187, 14, '0-999-095', 0, 92),
	(4188, 14, '0-999-096', 0, 93),
	(4189, 14, '0-999-097', 0, 94),
	(4190, 14, '0-999-098', 0, 95),
	(4191, 14, '0-999-099', 0, 96),
	(4192, 14, '0-999-101', 0, 97),
	(4193, 14, '0-999-102', 0, 98),
	(4194, 14, '0-999-103', 0, 99),
	(4195, 14, '0-999-104', 0, 100),
	(4196, 14, '0-999-105', 0, 101),
	(4197, 14, '0-999-106', 0, 102),
	(4198, 14, '0-999-107', 0, 103),
	(4199, 14, '0-999-108', 0, 104),
	(4200, 14, '0-999-109', 0, 105),
	(4201, 14, '0-999-110', 0, 106),
	(4202, 14, '0-999-111', 0, 107),
	(4203, 14, '0-999-112', 0, 108),
	(4204, 14, '0-999-113', 0, 109),
	(4205, 14, '0-999-114', 0, 110),
	(4206, 14, '0-999-115', 0, 111),
	(4207, 14, '0-999-116', 0, 112),
	(4208, 14, '0-999-117', 0, 113),
	(4209, 14, '0-999-118', 0, 114),
	(4210, 14, '0-999-119', 0, 115),
	(4211, 14, '0-999-120', 0, 116),
	(4212, 14, '0-999-121', 0, 117),
	(4213, 14, '0-999-122', 0, 118),
	(4214, 14, '0-999-123', 0, 119),
	(4215, 14, '0-999-124', 0, 120),
	(4216, 14, '0-999-125', 0, 121),
	(4217, 14, '0-999-126', 0, 122),
	(4218, 14, '0-999-127', 0, 123),
	(4219, 14, '0-999-128', 0, 124),
	(4220, 14, '0-999-129', 0, 125),
	(4221, 14, '0-999-130', 0, 126),
	(4222, 14, '0-999-131', 0, 127),
	(4223, 14, '0-999-132', 0, 128),
	(4224, 14, '0-999-133', 0, 129),
	(4225, 14, '0-999-134', 0, 130),
	(4226, 14, '0-999-135', 0, 131),
	(4227, 14, '0-999-136', 0, 132),
	(4228, 14, '0-999-137', 0, 133),
	(4229, 14, '0-999-138', 0, 134),
	(4230, 14, '0-999-139', 0, 135),
	(4231, 14, '0-999-140', 0, 136),
	(4232, 14, '0-999-141', 0, 137),
	(4233, 14, '0-999-142', 0, 138),
	(4234, 14, '0-999-144', 0, 139),
	(4235, 14, '0-999-145', 0, 140),
	(4236, 14, '0-999-146', 0, 141),
	(4237, 14, '0-999-147', 0, 142),
	(4238, 14, '0-999-148', 0, 143),
	(4239, 14, '0-999-149', 0, 144),
	(4240, 14, '0-999-150', 0, 145),
	(4241, 14, '0-999-151', 0, 146),
	(4242, 14, '0-999-152', 0, 147),
	(4243, 14, '0-999-153', 0, 148),
	(4244, 14, '0-999-154', 0, 149),
	(4245, 14, '0-999-155', 0, 150),
	(4246, 14, '0-999-156', 0, 151),
	(4247, 14, '0-999-157', 0, 152),
	(4248, 14, '0-999-158', 0, 153),
	(4249, 14, '0-999-159', 0, 154),
	(4250, 14, '0-999-160', 0, 155),
	(4251, 14, '0-999-161', 0, 156),
	(4252, 14, '0-999-162', 0, 157),
	(4253, 14, '0-999-163', 0, 158),
	(4254, 14, '0-999-164', 0, 159),
	(4255, 14, '0-999-165', 0, 160),
	(4256, 14, '0-999-166', 0, 161),
	(4257, 14, '0-999-167', 0, 162),
	(4258, 14, '0-999-168', 0, 163),
	(4259, 14, '0-999-169', 0, 164),
	(4260, 14, '0-999-170', 0, 165),
	(4261, 14, '0-999-171', 0, 166),
	(4262, 14, '0-999-172', 0, 167),
	(4263, 14, '0-999-173', 0, 168),
	(4264, 14, '0-999-174', 0, 169),
	(4265, 14, '0-999-175', 0, 170),
	(4266, 14, '0-999-176', 0, 171),
	(4267, 14, '0-999-177', 0, 172),
	(4268, 14, '1-999-001', 12, 173),
	(4269, 14, '1-999-002', 2, 174),
	(4270, 14, '1-999-003', 3, 175),
	(4271, 14, '1-999-004', 94, 176),
	(4272, 14, '1-999-005', 96, 177),
	(4273, 14, '1-999-006', 2, 178),
	(4274, 14, '1-999-007', 6, 179),
	(4275, 14, '1-999-008', 3, 180),
	(4276, 14, '1-999-009', 7, 181),
	(4277, 14, '1-999-010', 8, 182),
	(4278, 14, '1-999-011', 0, 183),
	(4279, 14, '1-999-012', 0, 184),
	(4280, 14, '1-999-013', 2, 185),
	(4281, 14, '1-999-014', 3, 186),
	(4282, 14, '1-999-015', 60, 187),
	(4283, 14, '1-999-016', 30, 188),
	(4284, 14, '1-999-017', 20, 189),
	(4285, 14, '1-999-018', 102, 190),
	(4286, 14, '1-999-019', 104, 191),
	(4287, 14, '1-999-020', 40, 192),
	(4288, 14, '1-999-021', 42, 193),
	(4289, 14, '1-999-022', 70, 194),
	(4290, 14, '1-999-023', 15, 195),
	(4291, 14, '1-999-024', 6, 196),
	(4292, 14, '1-999-025', 7, 197),
	(4293, 14, '1-999-026', 5, 198),
	(4294, 14, '1-999-027', 42, 199),
	(4295, 14, '1-999-028', 37, 200),
	(4296, 14, '1-999-029', 37, 201),
	(4297, 14, '1-999-030', 24, 202),
	(4298, 14, '1-999-031', 36, 203),
	(4299, 14, '1-999-032', 42, 204),
	(4300, 14, '1-999-033', 63, 205),
	(4301, 14, '1-999-034', 30, 206),
	(4302, 14, '1-999-035', 60, 207),
	(4303, 14, '1-999-036', 60, 208),
	(4304, 14, '1-999-037', 70, 209),
	(4305, 14, '1-999-038', 48, 210),
	(4306, 14, '1-999-039', 10, 211),
	(4307, 14, '1-999-040', 8, 212),
	(4308, 14, '1-999-041', 3, 213),
	(4309, 14, '1-999-042', 102, 214),
	(4310, 14, '1-999-043', 2, 215),
	(4311, 14, '1-999-044', 42, 216),
	(4312, 14, '1-999-045', 42, 217),
	(4313, 14, '1-999-046', 96, 218),
	(4314, 14, '1-999-047', 102, 219),
	(4315, 14, '1-999-048', 9, 220),
	(4316, 14, '1-999-049', 15, 221),
	(4317, 14, '1-999-050', 10, 222),
	(4318, 14, '1-999-051', 11, 223),
	(4319, 14, '1-999-052', 5, 224),
	(4320, 14, '1-999-053', 12, 225),
	(4321, 14, '1-999-054', 11, 226),
	(4322, 14, '1-999-055', 10, 227),
	(4323, 14, '1-999-056', 10, 228),
	(4324, 14, '1-999-057', 28, 229),
	(4325, 14, '1-999-058', 170, 230),
	(4326, 14, '1-999-059', 8, 231),
	(4327, 14, '1-999-060', 5, 232),
	(4328, 14, '1-999-061', 5, 233),
	(4329, 14, '1-999-062', 2, 234),
	(4330, 14, '1-999-063', 2, 235),
	(4331, 14, '1-999-064', 0, 236),
	(4332, 14, '1-999-065', 0, 237),
	(4333, 14, '1-999-066', 0, 238),
	(4334, 14, '1-999-077', 0, 239),
	(4335, 14, '2-999-000', 4, 240),
	(4336, 14, '2-999-001', 4, 241),
	(4337, 14, '2-999-002', 4, 242),
	(4338, 14, '2-999-003', 20, 243),
	(4339, 14, '2-999-004', 2, 244),
	(4340, 14, '2-999-005', 2, 245),
	(4341, 14, '2-999-006', 25, 246),
	(4342, 14, '2-999-007', 5, 247),
	(4343, 14, '2-999-008', 9, 248),
	(4344, 14, '2-999-009', 5, 249),
	(4345, 14, '2-999-012', 0, 250),
	(4346, 14, '2-999-013', 15, 251),
	(4347, 14, '2-999-014', 5, 252),
	(4348, 14, '2-999-015', 4, 253),
	(4349, 14, '2-999-016', 7, 254),
	(4350, 14, '2-999-017', 6, 255),
	(4351, 14, '2-999-018', 5, 256),
	(4352, 14, '2-999-020', 6, 257),
	(4353, 14, '2-999-021', 5, 258),
	(4354, 14, '2-999-022', 10, 259),
	(4355, 14, '2-999-023', 20, 260),
	(4356, 14, '2-999-024', 20, 261),
	(4357, 14, '2-999-025', 30, 262),
	(4358, 14, '2-999-026', 2, 263),
	(4359, 14, '2-999-027', 1, 264),
	(4360, 14, '2-999-028', 5, 265),
	(4361, 14, '2-999-029', 5, 266),
	(4362, 14, '2-999-030', 5, 267),
	(4363, 14, '2-999-031', 10, 268),
	(4364, 14, '2-999-032', 6, 269),
	(4365, 14, '2-999-033', 6, 270),
	(4366, 14, '2-999-034', 6, 271),
	(4367, 14, '2-999-035', 6, 272),
	(4368, 14, '2-999-036', 5, 273),
	(4369, 14, '2-999-037', 1, 274),
	(4370, 14, '2-999-038', 5, 275),
	(4371, 14, '2-999-039', 2, 276),
	(4372, 14, '2-999-041', 100, 277),
	(4373, 14, '2-999-042', 8, 278),
	(4374, 14, '2-999-043', 4, 279),
	(4375, 14, '2-999-044', 2, 280),
	(4376, 14, '2-999-045', 2, 281),
	(4377, 14, '2-999-046', 1, 282),
	(4378, 14, '2-999-047', 6, 283),
	(4379, 14, '2-999-048', 5, 284),
	(4380, 14, '2-999-049', 3, 285),
	(4381, 14, '2-999-050', 1, 286),
	(4382, 14, '2-999-051', 5, 287),
	(4383, 14, '2-999-052', 3, 288),
	(4384, 14, '2-999-053', 5, 289),
	(4385, 14, '2-999-054', 2, 290),
	(4386, 14, '2-999-055', 8, 291),
	(4387, 14, '2-999-056', 6, 292),
	(4388, 14, '2-999-057', 6, 293),
	(4389, 14, '2-999-058', 11, 294),
	(4390, 14, '2-999-059', 5, 295),
	(4391, 14, '2-999-061', 5, 296),
	(4392, 14, '2-999-062', 6, 297),
	(4393, 14, '2-999-063', 3, 298),
	(4394, 14, '2-999-065', 6, 299),
	(4395, 14, '2-999-066', 6, 300),
	(4396, 14, '2-999-067', 8, 301),
	(4397, 14, '2-999-070', 0, 302),
	(4398, 14, '2-999-071', 10, 303),
	(4399, 14, '2-999-074', 1, 304),
	(4400, 14, '2-999-075', 4, 305),
	(4401, 14, '2-999-076', 8, 306),
	(4402, 14, '2-999-077', 6, 307),
	(4403, 14, '2-999-078', 6, 308),
	(4404, 14, '2-999-079', 0, 309),
	(4405, 14, '2-999-080', 0, 310),
	(4406, 14, '2-999-081', 0, 311),
	(4407, 14, '2-999-082', 0, 312),
	(4408, 14, '2-999-083', 3, 313),
	(4409, 14, '2-999-084', 0, 314),
	(4410, 14, '2-999-085', 0, 315);
/*!40000 ALTER TABLE `tblservicetime` ENABLE KEYS */;


-- Dumping structure for table invndc.tblservicetype
DROP TABLE IF EXISTS `tblservicetype`;
CREATE TABLE IF NOT EXISTS `tblservicetype` (
  `idSrvcType` int(3) NOT NULL DEFAULT '0',
  `idBrand` int(3) DEFAULT NULL,
  `code` varchar(20) DEFAULT NULL,
  `operations` varchar(400) DEFAULT NULL,
  PRIMARY KEY (`idSrvcType`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblservicetype: 315 rows
/*!40000 ALTER TABLE `tblservicetype` DISABLE KEYS */;
INSERT INTO `tblservicetype` (`idSrvcType`, `idBrand`, `code`, `operations`) VALUES
	(1, 22, '0-999-000', 'Control diagrama distribuci¢\r'),
	(2, 22, '0-999-001', 'Engine cylinders compression test\r'),
	(3, 22, '0-999-002', 'Valve clearance adjustment\r'),
	(4, 22, '0-999-003', 'Timing belts adjustment\r'),
	(5, 22, '0-999-004', 'Engine oil pressure measurement\r'),
	(6, 22, '0-999-005', 'Spark plug check\r'),
	(7, 22, '0-999-006', 'Spark advance check (stroboscopic light lamp)\r'),
	(8, 22, '0-999-007', 'Ignition pick-up adjustment (injection)\r'),
	(9, 22, '0-999-008', 'Exhaust butterfly valve adjustment\r'),
	(10, 22, '0-999-010', 'Air filter cleaning or replacement\r'),
	(11, 22, '0-999-011', 'Fuel filter replacement\r'),
	(12, 22, '0-999-013', 'Engine oil and cartridge filter change\r'),
	(13, 22, '0-999-014', 'Coolant change\r'),
	(14, 22, '0-999-015', 'Battery check\r'),
	(15, 22, '0-999-016', 'Charging system check\r'),
	(16, 22, '0-999-017', 'Ignition system check\r'),
	(17, 22, '0-999-018', 'Errori Injection/ignition circuit check with DDS /deleting error from the memory/deleting error from the memory\r'),
	(18, 22, '0-999-019', 'Throttle Bowden cable adjustment\r'),
	(19, 22, '0-999-020', 'Starter Bowden cable adjustment\r'),
	(20, 22, '0-999-021', 'Front brakes hydraulic control pump fluid replacement\r'),
	(21, 22, '0-999-022', 'Rear brakes hydraulic control pump fluid replacement\r'),
	(22, 22, '0-999-023', 'Clutch hydraulic control pump oil replacement\r'),
	(23, 22, '0-999-024', 'Rear brake lever adjustment\r'),
	(24, 22, '0-999-025', 'Brake pads wear and brake fluid level check\r'),
	(25, 22, '0-999-026', 'Gear change lever adjustment\r'),
	(26, 22, '0-999-027', 'Chain tension adjustment\r'),
	(27, 22, '0-999-028', 'Wheel alignment check\r'),
	(28, 22, '0-999-029', 'Steering bearing play adjustment\r'),
	(29, 22, '0-999-030', 'Wheel bearings adjustment\r'),
	(30, 22, '0-999-031', 'Front fork oil change\r'),
	(31, 22, '0-999-032', 'Preload adjustment of rear shock absorber spring\r'),
	(32, 22, '0-999-033', 'wheel balancing\r'),
	(33, 22, '0-999-034', 'Rear wheel balancing\r'),
	(34, 22, '0-999-035', 'Nuts and bolts tightening check\r'),
	(35, 22, '0-999-036', 'Principale main wiring\r'),
	(36, 22, '0-999-037', 'Software ECU MTS1200 ECU software update recall Campaign\r'),
	(37, 22, '0-999-039', 'CR078 - C.T.780 CR078 - S.B.780 CR078 - C.T.780 CR078 - T.R.780 CR078 - C.T.780\r'),
	(38, 22, '0-999-041', 'Service 1000 km / 600 miles MTS 1200 Service 1000 km / 600 miles\r'),
	(39, 22, '0-999-042', 'Oil service MTS1200\r'),
	(40, 22, '0-999-043', 'Desmo service MTS 1200\r'),
	(41, 22, '0-999-044', 'Gear selector drum ratchet\r'),
	(42, 22, '0-999-045', 'Neutral light switch\r'),
	(43, 22, '0-999-046', 'Set of clutch plates\r'),
	(44, 22, '0-999-047', 'Clutch cover\r'),
	(45, 22, '0-999-048', 'Exhaust butterfly valve adjustment\r'),
	(46, 22, '0-999-049', 'Clutch drive shaft gear set (primary drive)\r'),
	(47, 22, '0-999-050', 'Clutch housing\r'),
	(48, 22, '0-999-051', 'Clutch pressure plate\r'),
	(49, 22, '0-999-052', 'Clutch drum\r'),
	(50, 22, '0-999-053', 'cylinder head gaskets + O-rings\r'),
	(51, 22, '0-999-054', 'Vertical cylinder head gaskets + O-rings\r'),
	(52, 22, '0-999-055', 'Horizontal cylinder head gaskets + O-rings\r'),
	(53, 22, '0-999-056', 'Crankshaft\r'),
	(54, 22, '0-999-057', 'Connecting rod assembly\r'),
	(55, 22, '0-999-058', 'Vertical cylinder\r'),
	(56, 22, '0-999-059', 'Horizontal cylinder\r'),
	(57, 22, '0-999-060', 'Horizontal and vertical cylinder-piston assembly\r'),
	(58, 22, '0-999-061', 'Timing gear set\r'),
	(59, 22, '0-999-062', 'Timing belt drive roller\r'),
	(60, 22, '0-999-063', 'Timing belts\r'),
	(61, 22, '0-999-064', 'Belt tensioning roller\r'),
	(62, 22, '0-999-065', 'Stripped vertical head\r'),
	(63, 22, '0-999-066', 'Vertical head camshaft\r'),
	(64, 22, '0-999-067', 'Horizontal head camshaft\r'),
	(65, 22, '0-999-068', 'Vertical and horizontal head opening rocker arm\r'),
	(66, 22, '0-999-069', 'Vertical and horizontal head closing rocker arm\r'),
	(67, 22, '0-999-070', 'Horizontal head valves\r'),
	(68, 22, '0-999-071', 'Vertical and horizontal head valves\r'),
	(69, 22, '0-999-072', 'Vertical head\r'),
	(70, 22, '0-999-073', 'Stripped horizontal head\r'),
	(71, 22, '0-999-074', 'Carburetor assy or throttle body\r'),
	(72, 22, '0-999-075', 'Oil pump\r'),
	(73, 22, '0-999-076', 'Intake net oil filter\r'),
	(74, 22, '0-999-077', 'Engine casings Carter comple\r'),
	(75, 22, '0-999-078', 'Breather valve Reniflard\r'),
	(76, 22, '0-999-079', 'Oil pump by-pass valve\r'),
	(77, 22, '0-999-080', 'Alternator\r'),
	(78, 22, '0-999-081', 'Coperchio lato catena completo Complete chain side cover\r'),
	(79, 22, '0-999-082', 'Complete starter motor\r'),
	(80, 22, '0-999-083', 'Complete pick-ups (RPM sensor)\r'),
	(81, 22, '0-999-084', 'Intermediate starter gear assembly\r'),
	(82, 22, '0-999-085', 'Starter clutch\r'),
	(83, 22, '0-999-086', 'Ignition flywheel\r'),
	(84, 22, '0-999-087', 'Complete engine\r'),
	(85, 22, '0-999-088', 'Complete engine overhaul\r'),
	(86, 22, '0-999-089', 'Complete exhaust system\r'),
	(87, 22, '0-999-090', 'Horizontal head exhaust pipe\r'),
	(88, 22, '0-999-091', 'Vert. head exhaust pipe\r'),
	(89, 22, '0-999-092', 'Silencer\r'),
	(90, 22, '0-999-093', 'Oil pressure switch\r'),
	(91, 22, '0-999-094', 'Oil cooler\r'),
	(92, 22, '0-999-095', 'Rear swingarm\r'),
	(93, 22, '0-999-096', 'Rear shock absorber\r'),
	(94, 22, '0-999-097', 'Headlight Phare\r'),
	(95, 22, '0-999-098', 'Instrument panel\r'),
	(96, 22, '0-999-099', 'Front subframe Structure\r'),
	(97, 22, '0-999-101', 'L.H. or R.H. front brake calipper\r'),
	(98, 22, '0-999-102', 'Front RH and LH brake caliper\r'),
	(99, 22, '0-999-103', 'Clutch lever pump\r'),
	(100, 22, '0-999-104', 'Handlebars Demi-guidons\r'),
	(101, 22, '0-999-105', 'gas Throttle transmission\r'),
	(102, 22, '0-999-106', 'R.H. or L.H. fork leg change Remplacement\r'),
	(103, 22, '0-999-107', 'Complete front fork\r'),
	(104, 22, '0-999-108', 'Fork overhaul\r'),
	(105, 22, '0-999-109', 'Left or right fork legs overhaul\r'),
	(106, 22, '0-999-110', 'Microswitch for front brake stop light\r'),
	(107, 22, '0-999-111', 'Rear brake master cylinder\r'),
	(108, 22, '0-999-112', 'Rear brake calipers\r'),
	(109, 22, '0-999-113', 'Front and rear wheel rim\r'),
	(110, 22, '0-999-114', 'Rear sprocket\r'),
	(111, 22, '0-999-115', 'Rear brake disc\r'),
	(112, 22, '0-999-116', 'Rear pads pair\r'),
	(113, 22, '0-999-117', 'Front brake disc\r'),
	(114, 22, '0-999-118', 'Front pads pair\r'),
	(115, 22, '0-999-119', 'Air box\r'),
	(116, 22, '0-999-120', 'Seat\r'),
	(117, 22, '0-999-121', 'Fuel tank\r'),
	(118, 22, '0-999-122', 'Fuel pump\r'),
	(119, 22, '0-999-123', 'Headlight fairing\r'),
	(120, 22, '0-999-124', 'Water cooler\r'),
	(121, 22, '0-999-125', 'Thermostat\r'),
	(122, 22, '0-999-126', 'Water pump fan\r'),
	(123, 22, '0-999-127', 'Expansion reservoir\r'),
	(124, 22, '0-999-128', 'water temperature gauge\r'),
	(125, 22, '0-999-129', 'Cooler return fitting\r'),
	(126, 22, '0-999-130', 'Horizontal cylinder fitting\r'),
	(127, 22, '0-999-131', 'Final drive Transmission secondaire\r'),
	(128, 22, '0-999-132', 'Rear frame\r'),
	(129, 22, '0-999-133', 'Fuel pipes\r'),
	(130, 22, '0-999-134', 'Tank cap\r'),
	(131, 22, '0-999-135', 'Side stand\r'),
	(132, 22, '0-999-136', 'Water inlet to horizontal cylinder\r'),
	(133, 22, '0-999-137', 'Central stand\r'),
	(134, 22, '0-999-138', 'Regolatore Rectifier R‚gulateur Regler Regulador\r'),
	(135, 22, '0-999-139', 'Wiring harness\r'),
	(136, 22, '0-999-140', 'ignition control unit\r'),
	(137, 22, '0-999-141', 'Battery\r'),
	(138, 22, '0-999-142', 'Air temperature sensor\r'),
	(139, 22, '0-999-144', 'Spark plugs\r'),
	(140, 22, '0-999-145', 'Throttle body\r'),
	(141, 22, '0-999-146', 'Injectors\r'),
	(142, 22, '0-999-147', 'Tail light assembly\r'),
	(143, 22, '0-999-148', 'Fuel level indicator\r'),
	(144, 22, '0-999-149', 'Electric fan\r'),
	(145, 22, '0-999-150', 'Starter solenoid\r'),
	(146, 22, '0-999-151', 'Side stand sensor\r'),
	(147, 22, '0-999-152', 'R.H. switch\r'),
	(148, 22, '0-999-153', 'L.H. switch\r'),
	(149, 22, '0-999-154', 'R.H. and L.H. switches\r'),
	(150, 22, '0-999-155', 'Immobilizer Antenna\r'),
	(151, 22, '0-999-156', 'R.H. or L.H. front turn indicators\r'),
	(152, 22, '0-999-157', 'R.H. or L.H. rear turn indicators\r'),
	(153, 22, '0-999-158', 'ABS unit\r'),
	(154, 22, '0-999-159', 'front ABS speed sensor\r'),
	(155, 22, '0-999-160', 'speed sensor\r'),
	(156, 22, '0-999-161', 'Exhaust butterfly valve actuator\r'),
	(157, 22, '0-999-162', 'Horizontal H.V. coil\r'),
	(158, 22, '0-999-163', 'Vertical H.V. coil\r'),
	(159, 22, '0-999-164', 'Suspension control unit\r'),
	(160, 22, '0-999-165', 'BBS control unit\r'),
	(161, 22, '0-999-166', 'Hands free CPU\r'),
	(162, 22, '0-999-167', 'Heated handgrip\r'),
	(163, 22, '0-999-168', 'Electrical fuel tank plug\r'),
	(164, 22, '0-999-169', 'RH side panniers lock\r'),
	(165, 22, '0-999-170', 'LH side panniers lock\r'),
	(166, 22, '0-999-171', 'Seat lock\r'),
	(167, 22, '0-999-172', 'Fuel tank plug lock\r'),
	(168, 22, '0-999-173', 'Lock set\r'),
	(169, 22, '0-999-174', 'S.B. 857 1199 rear suspension screw\r'),
	(170, 22, '0-999-175', 'Rear wheel eccentric hub lubrication\r'),
	(171, 22, '0-999-176', 'S.B. 866 MTS 1200 Vehicle Registration update - only ITA\r'),
	(172, 22, '0-999-177', 'S.B. 870 1199 engine control unit software update\r'),
	(173, 22, '1-999-001', 'Gear selector drum ratchet\r'),
	(174, 22, '1-999-002', 'Gear stopper (ball and spring)\r'),
	(175, 22, '1-999-003', 'Neutral light switch\r'),
	(176, 22, '1-999-004', 'Complete gearbox\r'),
	(177, 22, '1-999-005', 'Transmission gear\r'),
	(178, 22, '1-999-006', 'Set of clutch plates\r'),
	(179, 22, '1-999-007', 'Clutch cover\r'),
	(180, 22, '1-999-008', 'Clutch thrust piston assembly\r'),
	(181, 22, '1-999-009', 'Clutch housing bearings\r'),
	(182, 22, '1-999-010', 'Clutch drive shaft gear set (primary drive)\r'),
	(183, 22, '1-999-011', 'Clutch housing\r'),
	(184, 22, '1-999-012', 'Clutch housing oil seal\r'),
	(185, 22, '1-999-013', 'Clutch pressure plate\r'),
	(186, 22, '1-999-014', 'Clutch drum\r'),
	(187, 22, '1-999-015', 'Vert. and horiz. cylinder head gaskets + O-rings\r'),
	(188, 22, '1-999-016', 'Vertical cylinder head gaskets + O-rings\r'),
	(189, 22, '1-999-017', 'Horizontal cylinder head gaskets + O-rings\r'),
	(190, 22, '1-999-018', 'Crankshaft\r'),
	(191, 22, '1-999-019', 'Connecting rod assembly\r'),
	(192, 22, '1-999-020', 'Vertical cylinder\r'),
	(193, 22, '1-999-021', 'Horizontal cylinder\r'),
	(194, 22, '1-999-022', 'Horizontal and vertical cylinder-piston assembly (only\r'),
	(195, 22, '1-999-023', 'Timing gear set Couple engrenages de distrib.\r'),
	(196, 22, '1-999-024', 'Timing belt drive roller\r'),
	(197, 22, '1-999-025', 'Timing belts\r'),
	(198, 22, '1-999-026', 'Belt tensioning roller\r'),
	(199, 22, '1-999-027', 'Replacing bare vertical head\r'),
	(200, 22, '1-999-028', 'Vertical head camshaft\r'),
	(201, 22, '1-999-029', 'Horizontal head camshaft\r'),
	(202, 22, '1-999-030', 'Vertical and horizontal head opening rocker arm\r'),
	(203, 22, '1-999-031', 'Vertical and horizontal head closing rocker arm\r'),
	(204, 22, '1-999-032', 'Horizontal head valves\r'),
	(205, 22, '1-999-033', 'Vertical and horizontal head valves\r'),
	(206, 22, '1-999-034', 'Vertical head valves\r'),
	(207, 22, '1-999-035', 'Horizontal head valve guides\r'),
	(208, 22, '1-999-036', 'Vertical head valve guides\r'),
	(209, 22, '1-999-037', 'Horiz. and vertical head valve guides\r'),
	(210, 22, '1-999-038', 'Stripped horizontal head\r'),
	(211, 22, '1-999-039', 'Carburetor assy or throttle body\r'),
	(212, 22, '1-999-040', 'Oil pump\r'),
	(213, 22, '1-999-041', 'Intake net oil filter\r'),
	(214, 22, '1-999-042', 'Engine casings\r'),
	(215, 22, '1-999-043', 'Breather valve\r'),
	(216, 22, '1-999-044', 'Horiz. head-to-cylinder stud bolt\r'),
	(217, 22, '1-999-045', 'Vertical head-to-cylinder stud bolt\r'),
	(218, 22, '1-999-046', 'Gearbox shaft bearings\r'),
	(219, 22, '1-999-047', 'Crankshaft bearings\r'),
	(220, 22, '1-999-048', 'Oil pump by-pass valve\r'),
	(221, 22, '1-999-049', 'Alternator\r'),
	(222, 22, '1-999-050', 'Complete chain side cover\r'),
	(223, 22, '1-999-051', 'Complete starter motor\r'),
	(224, 22, '1-999-052', 'Complete pick-ups (RPM sensor)\r'),
	(225, 22, '1-999-053', 'Intermediate starter gear assembly\r'),
	(226, 22, '1-999-054', 'Starter clutch roller bearing\r'),
	(227, 22, '1-999-055', 'Starter clutch\r'),
	(228, 22, '1-999-056', 'Ignition flywheel\r'),
	(229, 22, '1-999-057', 'Complete engine\r'),
	(230, 22, '1-999-058', 'Complete engine (overhaul)\r'),
	(231, 22, '1-999-059', 'Complete exhaust system\r'),
	(232, 22, '1-999-060', 'Horizontal head exhaust pipe\r'),
	(233, 22, '1-999-061', 'Vert. head exhaust pipe\r'),
	(234, 22, '1-999-062', 'Silencer\r'),
	(235, 22, '1-999-063', 'Oil pressure switch\r'),
	(236, 22, '1-999-064', 'Change coolant\r'),
	(237, 22, '1-999-065', 'Changing the external vertical valve cover seal\r'),
	(238, 22, '1-999-066', 'Changing the external horizontal valve cover seal\r'),
	(239, 22, '1-999-077', 'Side stand\r'),
	(240, 22, '2-999-000', 'Oil cooler\r'),
	(241, 22, '2-999-001', 'Oil delivery pipe to cooler\r'),
	(242, 22, '2-999-002', 'Oil return pipe from cooler\r'),
	(243, 22, '2-999-003', 'Rear swingarm\r'),
	(244, 22, '2-999-004', 'Upper chain sliding shoe\r'),
	(245, 22, '2-999-005', 'Lower chain sliding shoe\r'),
	(246, 22, '2-999-006', 'Needle roller bearing on rear swingarm\r'),
	(247, 22, '2-999-007', 'Rear shock absorber\r'),
	(248, 22, '2-999-008', 'Headlight\r'),
	(249, 22, '2-999-009', 'Headlight bulb\r'),
	(250, 22, '2-999-012', 'Instrument panel\r'),
	(251, 22, '2-999-013', 'Front subframe Structure\r'),
	(252, 22, '2-999-014', 'Front brake master cylinder\r'),
	(253, 22, '2-999-015', 'L.H. or R.H. front brake calipper\r'),
	(254, 22, '2-999-016', 'Front RH and LH brake caliper\r'),
	(255, 22, '2-999-017', 'Clutch lever pump\r'),
	(256, 22, '2-999-018', 'Handlebars\r'),
	(257, 22, '2-999-020', 'Throttle transmission\r'),
	(258, 22, '2-999-021', 'R.H. or L.H. fork leg change Remplacement\r'),
	(259, 22, '2-999-022', 'Complete front fork\r'),
	(260, 22, '2-999-023', 'Steering bearings change\r'),
	(261, 22, '2-999-024', 'Fork overhaul\r'),
	(262, 22, '2-999-025', 'Left or right fork legs overhaul\r'),
	(263, 22, '2-999-026', 'Front brake control lever or clutch\r'),
	(264, 22, '2-999-027', 'Microswitch for front brake stop light\r'),
	(265, 22, '2-999-028', 'Brake line\r'),
	(266, 22, '2-999-029', 'Rear brake master cylinder\r'),
	(267, 22, '2-999-030', 'Rear brake calipers\r'),
	(268, 22, '2-999-031', 'Front and rear wheel rim\r'),
	(269, 22, '2-999-032', 'Front wheel hub bearing\r'),
	(270, 22, '2-999-033', 'Rear wheel bearings\r'),
	(271, 22, '2-999-034', 'Rubber cush drive on rear wheel assembly\r'),
	(272, 22, '2-999-035', 'Rear sprocket\r'),
	(273, 22, '2-999-036', 'Rear brake disc\r'),
	(274, 22, '2-999-037', 'Rear pads pair\r'),
	(275, 22, '2-999-038', 'Front brake disc\r'),
	(276, 22, '2-999-039', 'Front pads pair\r'),
	(277, 22, '2-999-041', 'Frame\r'),
	(278, 22, '2-999-042', 'Air box\r'),
	(279, 22, '2-999-043', 'Oil breather reservoir\r'),
	(280, 22, '2-999-044', 'Gear change lever\r'),
	(281, 22, '2-999-045', 'Footpeg support plate\r'),
	(282, 22, '2-999-046', 'Seat\r'),
	(283, 22, '2-999-047', 'Fuel tank\r'),
	(284, 22, '2-999-048', 'Tank cover\r'),
	(285, 22, '2-999-049', 'Fuel pump\r'),
	(286, 22, '2-999-050', 'Rear mudguard\r'),
	(287, 22, '2-999-051', 'Front mudguard\r'),
	(288, 22, '2-999-052', 'Headlight fairing\r'),
	(289, 22, '2-999-053', 'Upper or lower body panel (undersump)\r'),
	(290, 22, '2-999-054', 'Air scoop\r'),
	(291, 22, '2-999-055', 'Rear view mirror\r'),
	(292, 22, '2-999-056', 'Water cooler\r'),
	(293, 22, '2-999-057', 'Thermostat\r'),
	(294, 22, '2-999-058', 'Water inlet to vertical cylinder\r'),
	(295, 22, '2-999-059', 'Water pump fan\r'),
	(296, 22, '2-999-061', 'Expansion reservoir\r'),
	(297, 22, '2-999-062', 'Engine / water temperature gauge\r'),
	(298, 22, '2-999-063', 'Cylinder thermostat fitting\r'),
	(299, 22, '2-999-065', 'Cooler return fitting\r'),
	(300, 22, '2-999-066', 'Horizontal cylinder fitting\r'),
	(301, 22, '2-999-067', 'Final drive\r'),
	(302, 22, '2-999-070', 'Rear frame\r'),
	(303, 22, '2-999-071', 'Fuel pipes\r'),
	(304, 22, '2-999-074', 'Tank cap\r'),
	(305, 22, '2-999-075', 'Seat lock\r'),
	(306, 22, '2-999-076', 'Keys kit\r'),
	(307, 22, '2-999-077', 'Side stand\r'),
	(308, 22, '2-999-078', 'Water inlet to horizontal cylinder\r'),
	(309, 22, '2-999-079', 'R.H. fork leg change\r'),
	(310, 22, '2-999-080', 'Changing the fuel pipes\r'),
	(311, 22, '2-999-081', 'MTS1200 Fuel tank RC |  X ring\r'),
	(312, 22, '2-999-082', 'Central stand\r'),
	(313, 22, '2-999-083', 'Replacing rear brake pads - SB n. 851\r'),
	(314, 22, '2-999-084', 'Rear suspension linkage\r'),
	(315, 22, '2-999-085', 'Replacing exhaust valve cable heat guard\r');
/*!40000 ALTER TABLE `tblservicetype` ENABLE KEYS */;


-- Dumping structure for table invndc.tblstockroom
DROP TABLE IF EXISTS `tblstockroom`;
CREATE TABLE IF NOT EXISTS `tblstockroom` (
  `idSkRm` int(5) NOT NULL DEFAULT '0',
  `stockRm` varchar(50) DEFAULT NULL,
  `detail` varchar(150) DEFAULT NULL,
  PRIMARY KEY (`idSkRm`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblstockroom: 4 rows
/*!40000 ALTER TABLE `tblstockroom` DISABLE KEYS */;
INSERT INTO `tblstockroom` (`idSkRm`, `stockRm`, `detail`) VALUES
	(1, 'PARTS SERVICE A', 'PARTS SERVICE A'),
	(2, 'VESPA ACCESSORIES B', 'VESPA ACCESSORIES B'),
	(3, 'KAWASAKI PARTS C', 'KAWASAKI PARTS C'),
	(4, 'NDC', 'NDC');
/*!40000 ALTER TABLE `tblstockroom` ENABLE KEYS */;


-- Dumping structure for table invndc.tblsupplier
DROP TABLE IF EXISTS `tblsupplier`;
CREATE TABLE IF NOT EXISTS `tblsupplier` (
  `idSupplier` int(15) NOT NULL DEFAULT '0',
  `supplierName` varchar(150) DEFAULT NULL,
  `code` varchar(10) DEFAULT NULL,
  `detail` varchar(200) DEFAULT NULL,
  `address` varchar(150) DEFAULT NULL,
  `phoneNum` varchar(15) DEFAULT NULL,
  `faxNum` varchar(15) DEFAULT NULL,
  `website` varchar(20) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `taxStatus` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idSupplier`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblsupplier: ~21 rows (approximately)
/*!40000 ALTER TABLE `tblsupplier` DISABLE KEYS */;
INSERT INTO `tblsupplier` (`idSupplier`, `supplierName`, `code`, `detail`, `address`, `phoneNum`, `faxNum`, `website`, `status`, `taxStatus`) VALUES
	(0, 'Other', '0', 'Other', 'Philippines', 'none', 'none', 'none', 'new', 'VAT'),
	(1, 'DANS Bike Shop Inc.', 'D1', 'Bell Helmet, MSR Helmet and Ridefit, Itrack, Airmatic Apparels Supplier', 'W13-A La Fuerza Plaza Compound 2241 Don Chino Roces Ave., Makati City, Philippines', '8945514', '8945110', 'www.dans.ph', 'new', 'VAT'),
	(2, 'Infiniteserv', 'I2', 'KYT Helmet Supplier', 'Manila City, Philippines', 'none', 'none', 'none', 'new', ''),
	(3, 'Performance Parts Corp.', 'P3', 'Pirelli and Metzeler Tires and Motorex Oils Supplier', '#11 St., Project 8, Bahay Toro 1, Quezon City, Philippines', '3657274', '3616941', 'none', 'new', 'VAT'),
	(4, 'Caloocan Sales Center Inc.', 'C4', 'After Market Parts and Accessories Supplier', '340-342 Rizal Avenue Extension Grace Park, Caloocan City, Philippines 1400', '3643652', '3616941', 'none', 'new', 'VAT'),
	(5, 'Access Plus', 'A5', 'Ducati & KTM Parts and Accessories Supplier', '102 P. Tuazon St., Cubao, Metro Manila, Philippines', '7246704', '4141184', 'none', 'new', 'VAT'),
	(6, 'TA MARKETING', 'T6', 'Ducati Bikes Supplier', 'TA MARKETING', 'none', 'none', 'none', 'new', ''),
	(7, 'Granstar Motor Industrial Corp', 'G7', 'KTM Vespa Aprilia Moto Guzzi Husqvarna Bikes and Parts and Apparel Alpinestar', '7 and 9 Brixton St. Brgy. Kapitolyo, Pasig City, Philippines', '025706137', '022349177', 'none', 'new', 'VAT'),
	(8, 'EMCOR KAWASAKI Davao', 'E8', 'Kawasaki Unit Supplier', 'J.P. Laurel Ave., Bajada, Davao City, Philippines', '0822221125-32', '0822250507', 'none', 'new', 'VAT'),
	(9, 'TOURATECH', 'T9', 'After Market Accessories Supplier', '124 Pelbel 2. Shaw Blvd, San Juan City, Philippines', '09174326639', '026319388', 'none', 'new', 'NON-VAT'),
	(10, 'Scooter Depot PH', 'S10', 'Vespa Accessories Supplier', 'Manila City, Philippines', 'none', 'none', 'none', 'new', 'NON-VAT'),
	(11, 'Sunreach Distribution Corporation', 'S11', 'Castrol Oils and Lubricants Supplier', 'Unit 18-A , J.King and Sons Warehouse, Maa Road, Davao City, Philippines', '2240546', '2822486', 'none', 'new', 'VAT'),
	(12, 'Kawasaki', 'K12', 'Parts Supplier', 'Km. 23 East Service Road, Bo. Cupang, Muntinlupa City, Metro Manila, Philippines', '8423140', '8427648', 'kawasaki.com.ph', 'new', NULL),
	(13, 'Mars Agri Ventures', 'M13', 'Shell Oils and Lubricants Supplier', 'Davao City, Philippines', 'none', 'none', 'none', 'new', 'VAT'),
	(14, 'GMJC Protrac Mktg', 'G14', 'After Market Parts and Accessories Supplier', 'Rizal Ext. Corner De Jesus St. Davao City, Philippines', '0823000464', 'none', 'protracmktg', 'new', 'VAT'),
	(15, 'Mindanao Global Distributors', 'M15', 'Total Oils and Lubricants', 'Km. 5, Buhangin Road, Davao City, Philippines', '2846145', 'none', 'none', 'new', 'VAT'),
	(16, 'Roshan Commercial Corporation', 'R16', 'Spyder Helmet Supplier', 'none', 'none', 'none', 'none', 'new', NULL),
	(17, 'RNM Dynamics Philippines Inc.', 'R17', 'Toyo Adtec Sparkplugs Supplier', 'Manila City', NULL, NULL, NULL, 'new', 'VAT'),
	(18, 'Mototechnik Inc', 'M18', 'Vespa Bikes and Parts and Accessories Supplier', 'Manila City', 'none', 'none', 'none', 'new', 'VAT'),
	(19, 'Apexx Express - Julian Goitia', 'A19', 'Multibrand Parts, Accessories and Apparels Merchandise (Order Basis)', 'Manila City', 'none', 'none', 'none', 'none', 'NON-VAT'),
	(20, 'PUMA', 'P20', 'Ducati Apparels and Merchandise Supplier', 'none', 'none', 'none', 'none', 'new', 'VAT'),
	(21, 'Cris Performance', 'C25', 'After Market Supplier', 'None', 'none', 'none', 'none', 'new', 'NON-VAT');
/*!40000 ALTER TABLE `tblsupplier` ENABLE KEYS */;


-- Dumping structure for table invndc.tblsuppliercontact
DROP TABLE IF EXISTS `tblsuppliercontact`;
CREATE TABLE IF NOT EXISTS `tblsuppliercontact` (
  `idContact` int(15) DEFAULT NULL,
  `idSupplier` int(15) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `address` varchar(100) DEFAULT NULL,
  `contactNo` varchar(30) DEFAULT NULL,
  `emailAdd` varchar(30) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblsuppliercontact: 0 rows
/*!40000 ALTER TABLE `tblsuppliercontact` DISABLE KEYS */;
/*!40000 ALTER TABLE `tblsuppliercontact` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpinventory
DROP TABLE IF EXISTS `tbltmpinventory`;
CREATE TABLE IF NOT EXISTS `tbltmpinventory` (
  `idItem` int(10) DEFAULT NULL,
  `poID` varchar(15) DEFAULT NULL,
  `roID` varchar(15) DEFAULT NULL,
  `soID` varchar(15) DEFAULT NULL,
  `item` varchar(100) DEFAULT NULL,
  `detail` varchar(500) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `cost` double(15,2) DEFAULT NULL,
  `in` int(3) DEFAULT NULL,
  `out` int(3) DEFAULT NULL,
  `balance` int(3) DEFAULT NULL,
  `date` date DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbltmpinventory: 0 rows
/*!40000 ALTER TABLE `tbltmpinventory` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmpinventory` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpjoitems
DROP TABLE IF EXISTS `tbltmpjoitems`;
CREATE TABLE IF NOT EXISTS `tbltmpjoitems` (
  `idJOI` int(15) NOT NULL DEFAULT '0',
  `idItem` int(15) DEFAULT NULL,
  `idSrvcItem` int(10) DEFAULT NULL,
  `unit` varchar(10) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `unitPrice` double(12,2) DEFAULT NULL,
  `discount` int(3) DEFAULT NULL,
  `amntDscnt` double(15,2) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `remarks` text,
  `idJO` int(15) DEFAULT NULL,
  `joID` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idJOI`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbltmpjoitems: 1 rows
/*!40000 ALTER TABLE `tbltmpjoitems` DISABLE KEYS */;
INSERT INTO `tbltmpjoitems` (`idJOI`, `idItem`, `idSrvcItem`, `unit`, `qty`, `unitPrice`, `discount`, `amntDscnt`, `amount`, `status`, `remarks`, `idJO`, `joID`) VALUES
	(75, 291, 0, 'Set(s)', 1, 6490.00, 20, 1298.00, 5192.00, 'Issued', 'job order', 58, '2015-58');
/*!40000 ALTER TABLE `tbltmpjoitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpordereditems
DROP TABLE IF EXISTS `tbltmpordereditems`;
CREATE TABLE IF NOT EXISTS `tbltmpordereditems` (
  `pk` int(15) NOT NULL AUTO_INCREMENT,
  `idOrder` int(10) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `quantity` int(3) NOT NULL,
  `idUnit` int(2) DEFAULT NULL,
  `cost` double(12,2) unsigned zerofill DEFAULT NULL,
  `balance` int(5) DEFAULT NULL,
  `status` varchar(15) DEFAULT NULL,
  `qtypending` int(5) NOT NULL,
  `qtyreceived` int(5) NOT NULL,
  `qtyreturned` int(5) NOT NULL,
  `returnRemarks` varchar(100) NOT NULL,
  `dateReceived` date DEFAULT NULL,
  `srp` double(18,2) DEFAULT NULL,
  `dealerPrice` double(18,2) DEFAULT NULL,
  `remarks` varchar(30) DEFAULT NULL,
  `roID` varchar(15) DEFAULT NULL,
  `taxStatus` varchar(25) DEFAULT NULL,
  `idSupplier` int(10) DEFAULT NULL,
  PRIMARY KEY (`pk`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 ROW_FORMAT=COMPACT;

-- Dumping data for table invndc.tbltmpordereditems: ~0 rows (approximately)
/*!40000 ALTER TABLE `tbltmpordereditems` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmpordereditems` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmppulloutbikes
DROP TABLE IF EXISTS `tbltmppulloutbikes`;
CREATE TABLE IF NOT EXISTS `tbltmppulloutbikes` (
  `idPOB` int(15) NOT NULL DEFAULT '0',
  `idItem` int(15) DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `idPOI` int(15) DEFAULT NULL,
  `idPullOut` int(15) DEFAULT NULL,
  `pulloutID` varchar(50) DEFAULT NULL,
  `status` varchar(25) DEFAULT NULL,
  `remarks` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`idPOB`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;

-- Dumping data for table invndc.tbltmppulloutbikes: 0 rows
/*!40000 ALTER TABLE `tbltmppulloutbikes` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmppulloutbikes` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmppulloutitems
DROP TABLE IF EXISTS `tbltmppulloutitems`;
CREATE TABLE IF NOT EXISTS `tbltmppulloutitems` (
  `idPOI` int(25) DEFAULT NULL,
  `idItem` int(15) DEFAULT NULL,
  `qty` int(5) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `unitPrice` double(15,2) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `status` varchar(25) DEFAULT NULL,
  `remarks` varchar(100) DEFAULT NULL,
  `idPullOut` int(15) DEFAULT NULL,
  `pulloutID` varchar(15) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;

-- Dumping data for table invndc.tbltmppulloutitems: 0 rows
/*!40000 ALTER TABLE `tbltmppulloutitems` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmppulloutitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpqcharges
DROP TABLE IF EXISTS `tbltmpqcharges`;
CREATE TABLE IF NOT EXISTS `tbltmpqcharges` (
  `idCharges` int(3) unsigned NOT NULL AUTO_INCREMENT,
  `details` varchar(100) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `idQtrans` int(11) NOT NULL,
  `qno` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idCharges`)
) ENGINE=MyISAM AUTO_INCREMENT=5 DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;

-- Dumping data for table invndc.tbltmpqcharges: 0 rows
/*!40000 ALTER TABLE `tbltmpqcharges` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmpqcharges` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpqtrans
DROP TABLE IF EXISTS `tbltmpqtrans`;
CREATE TABLE IF NOT EXISTS `tbltmpqtrans` (
  `idQtrans` int(10) NOT NULL DEFAULT '0',
  `qno` varchar(10) DEFAULT NULL,
  `itemName` varchar(150) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `ciwaog` double(15,2) DEFAULT NULL,
  `ciwoaog` double(15,2) DEFAULT NULL,
  `preparedBy` varchar(25) DEFAULT NULL,
  `conforme` varchar(25) DEFAULT NULL,
  `dateTrans` date DEFAULT NULL,
  `insurance` varchar(50) DEFAULT NULL,
  `insuExpiry` date DEFAULT NULL,
  `idMtrbikes` int(10) DEFAULT NULL,
  PRIMARY KEY (`idQtrans`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;

-- Dumping data for table invndc.tbltmpqtrans: 0 rows
/*!40000 ALTER TABLE `tbltmpqtrans` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmpqtrans` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpreserveitems
DROP TABLE IF EXISTS `tbltmpreserveitems`;
CREATE TABLE IF NOT EXISTS `tbltmpreserveitems` (
  `idRsrvItem` int(15) NOT NULL AUTO_INCREMENT,
  `idItem` int(15) DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `itemName` varchar(250) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `qty` int(5) DEFAULT NULL,
  `unitPrice` double(12,2) DEFAULT NULL,
  `amount` double(15,2) DEFAULT NULL,
  `status` varchar(20) DEFAULT NULL,
  `remarks` text,
  `idRsrv` int(10) DEFAULT NULL,
  `rsrvNo` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idRsrvItem`)
) ENGINE=MyISAM AUTO_INCREMENT=43 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbltmpreserveitems: 1 rows
/*!40000 ALTER TABLE `tbltmpreserveitems` DISABLE KEYS */;
INSERT INTO `tbltmpreserveitems` (`idRsrvItem`, `idItem`, `idMtrbikes`, `itemName`, `unit`, `qty`, `unitPrice`, `amount`, `status`, `remarks`, `idRsrv`, `rsrvNo`) VALUES
	(42, 0, 0, 'Downpayment - Kawasaki Ninja 1000 Gray 2016', '', 0, 0.00, 100000.00, 'AR', '', 30, '2015-30');
/*!40000 ALTER TABLE `tbltmpreserveitems` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltmpsales
DROP TABLE IF EXISTS `tbltmpsales`;
CREATE TABLE IF NOT EXISTS `tbltmpsales` (
  `idSales` int(15) NOT NULL DEFAULT '0',
  `idItem` int(10) DEFAULT NULL,
  `unit` varchar(15) DEFAULT NULL,
  `qty` int(3) DEFAULT NULL,
  `unitPrice` double(15,2) DEFAULT NULL,
  `cost` double(15,2) DEFAULT NULL,
  `discount` int(3) DEFAULT NULL,
  `amntDscnt` double(18,2) DEFAULT NULL,
  `amount` double(18,2) DEFAULT NULL,
  `id` int(15) DEFAULT NULL,
  `soID` varchar(25) DEFAULT NULL,
  `status` varchar(30) DEFAULT NULL,
  `idMtrbikes` int(15) DEFAULT NULL,
  `remarks` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`idSales`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC;

-- Dumping data for table invndc.tbltmpsales: 0 rows
/*!40000 ALTER TABLE `tbltmpsales` DISABLE KEYS */;
/*!40000 ALTER TABLE `tbltmpsales` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltransaction
DROP TABLE IF EXISTS `tbltransaction`;
CREATE TABLE IF NOT EXISTS `tbltransaction` (
  `idTrans` int(2) DEFAULT NULL,
  `transaction` varchar(80) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbltransaction: 3 rows
/*!40000 ALTER TABLE `tbltransaction` DISABLE KEYS */;
INSERT INTO `tbltransaction` (`idTrans`, `transaction`) VALUES
	(1, 'Cash'),
	(2, 'Financing'),
	(3, 'Trade In');
/*!40000 ALTER TABLE `tbltransaction` ENABLE KEYS */;


-- Dumping structure for table invndc.tbltranstype
DROP TABLE IF EXISTS `tbltranstype`;
CREATE TABLE IF NOT EXISTS `tbltranstype` (
  `idTransType` int(2) DEFAULT NULL,
  `transType` varchar(50) DEFAULT NULL,
  `idTrans` int(2) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tbltranstype: 5 rows
/*!40000 ALTER TABLE `tbltranstype` DISABLE KEYS */;
INSERT INTO `tbltranstype` (`idTransType`, `transType`, `idTrans`) VALUES
	(1, 'BPI', 2),
	(2, 'Sumisho', 2),
	(3, 'Malayan Leasing', 2),
	(4, 'Orix Metro', 2),
	(5, 'AFC', 2);
/*!40000 ALTER TABLE `tbltranstype` ENABLE KEYS */;


-- Dumping structure for table invndc.tblunit
DROP TABLE IF EXISTS `tblunit`;
CREATE TABLE IF NOT EXISTS `tblunit` (
  `idUnit` int(2) NOT NULL AUTO_INCREMENT,
  `Unit` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`idUnit`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=latin1;

-- Dumping data for table invndc.tblunit: ~14 rows (approximately)
/*!40000 ALTER TABLE `tblunit` DISABLE KEYS */;
INSERT INTO `tblunit` (`idUnit`, `Unit`) VALUES
	(1, 'Pc(s)'),
	(2, 'Bag(s)'),
	(3, 'Unit(s)'),
	(4, 'Ltr(s)'),
	(5, 'ML'),
	(6, 'G'),
	(7, 'GL'),
	(8, 'KIT'),
	(9, 'Set(s)'),
	(10, 'Pack(s)'),
	(11, 'Lot'),
	(12, 'Pair(s)'),
	(13, 'Box(es)'),
	(14, 'Hr(s)'),
	(15, 'Bot');
/*!40000 ALTER TABLE `tblunit` ENABLE KEYS */;


-- Dumping structure for view invndc.vw_companyinfo
DROP VIEW IF EXISTS `vw_companyinfo`;
-- Creating temporary table to overcome VIEW dependency errors
CREATE TABLE `vw_companyinfo` (
	`Fullname` VARCHAR(55) NOT NULL COLLATE 'latin1_swedish_ci',
	`idEmp` INT(10) NOT NULL,
	`Address_1` VARCHAR(150) NOT NULL COLLATE 'latin1_swedish_ci',
	`Address_2` VARCHAR(150) NOT NULL COLLATE 'latin1_swedish_ci',
	`TelNum` VARCHAR(50) NOT NULL COLLATE 'latin1_swedish_ci',
	`Web` VARCHAR(50) NOT NULL COLLATE 'latin1_swedish_ci',
	`TINo` VARCHAR(20) NOT NULL COLLATE 'latin1_swedish_ci',
	`B_Company` VARCHAR(100) NOT NULL COLLATE 'latin1_swedish_ci'
) ENGINE=MyISAM;


-- Dumping structure for view invndc.vw_pulloutitems
DROP VIEW IF EXISTS `vw_pulloutitems`;
-- Creating temporary table to overcome VIEW dependency errors
CREATE TABLE `vw_pulloutitems` (
	`ID_POI` BIGINT(25) NOT NULL,
	`puID` VARCHAR(15) NOT NULL COLLATE 'latin1_swedish_ci',
	`Code_No` BIGINT(15) NOT NULL,
	`POI_Qty` BIGINT(11) NOT NULL,
	`POI_UoM` VARCHAR(15) NOT NULL COLLATE 'latin1_swedish_ci',
	`POI_Item` VARCHAR(250) NOT NULL COLLATE 'latin1_swedish_ci',
	`POI_UPrice` DOUBLE(15,2) NOT NULL,
	`POI_Stat` VARCHAR(25) NOT NULL COLLATE 'latin1_swedish_ci',
	`POI_Rmrks` VARCHAR(100) NOT NULL COLLATE 'latin1_swedish_ci',
	`Part_No` VARCHAR(20) NOT NULL COLLATE 'latin1_swedish_ci',
	`Inv_Cost` DOUBLE(15,2) NOT NULL,
	`ID_Bike` BIGINT(15) NOT NULL
) ENGINE=MyISAM;


-- Dumping structure for view invndc.vw_companyinfo
DROP VIEW IF EXISTS `vw_companyinfo`;
-- Removing temporary table and create final VIEW structure
DROP TABLE IF EXISTS `vw_companyinfo`;
CREATE ALGORITHM=UNDEFINED DEFINER=`user`@`192.168.1.3` SQL SECURITY DEFINER VIEW `vw_companyinfo` AS select ifnull(concat(`e`.`fName`,_latin1' ',`e`.`midInit`,_latin1'. ',`e`.`lName`),_latin1'_') AS `Fullname`,`e`.`idEmp` AS `idEmp`,ifnull(`c`.`address1`,_latin1'') AS `Address_1`,ifnull(`c`.`address2`,_latin1'') AS `Address_2`,ifnull(`c`.`phoneNum`,_latin1'') AS `TelNum`,ifnull(`c`.`website`,_latin1'') AS `Web`,ifnull(`c`.`TIN`,_latin1'') AS `TINo`,ifnull(`c`.`company`,_latin1'_') AS `B_Company` from ((`tblemployee` `e` left join `tblcompany` `c` on((`c`.`idCmpny` = `e`.`idCmpny`))) left join `tbllocation` `l` on(`l`.`idLocation`));


-- Dumping structure for view invndc.vw_pulloutitems
DROP VIEW IF EXISTS `vw_pulloutitems`;
-- Removing temporary table and create final VIEW structure
DROP TABLE IF EXISTS `vw_pulloutitems`;
CREATE ALGORITHM=UNDEFINED DEFINER=`user`@`192.168.1.3` SQL SECURITY DEFINER VIEW `vw_pulloutitems` AS select ifnull(`pi`.`idPOI`,0) AS `ID_POI`,ifnull(`pi`.`pulloutID`,0) AS `puID`,ifnull(`i`.`code`,0) AS `Code_No`,ifnull(`pi`.`qty`,0) AS `POI_Qty`,ifnull(`pi`.`unit`,_latin1'_') AS `POI_UoM`,ifnull(`i`.`itemName`,_latin1'_') AS `POI_Item`,ifnull(`pi`.`unitPrice`,0) AS `POI_UPrice`,ifnull(`pi`.`status`,_latin1'_') AS `POI_Stat`,ifnull(`pi`.`remarks`,_latin1'_') AS `POI_Rmrks`,ifnull(`i`.`partNum`,_latin1'_') AS `Part_No`,ifnull(`inv`.`cost`,0) AS `Inv_Cost`,ifnull(`pb`.`idMtrbikes`,0) AS `ID_Bike` from (((`tbltmppulloutitems` `pi` left join `tblitem` `i` on((`i`.`code` = `pi`.`idItem`))) left join `tblinventory` `inv` on((`inv`.`code` = `pi`.`idItem`))) left join `tbltmppulloutbikes` `pb` on((`pb`.`idItem` = `pi`.`idItem`)));
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IF(@OLD_FOREIGN_KEY_CHECKS IS NULL, 1, @OLD_FOREIGN_KEY_CHECKS) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;

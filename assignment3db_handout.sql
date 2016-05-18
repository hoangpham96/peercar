/* 
 * INFO2120 / INFO2820
 * Database Systems I
 *
 * Reference Schema for INFo2120/2820 Assignment - Car-Sharing Database
 * version 3.0
 *
 * PostgreSQL version...
 *
 * IMPORTANT!
 * You need to replace <your-login> with your PostgreSQL user name in line 311
 * of this file (the ALTER USER  command)
 */

/* clean-up to make script idempotent */
BEGIN TRANSACTION;
 SET search_Path = CarSharing, '$user', public, unidb;
 DROP TABLE IF EXISTS TripLog;
 DROP TABLE IF EXISTS Computer;
 DROP TABLE IF EXISTS Rating;
 DROP TABLE IF EXISTS Review;
 DROP TABLE IF EXISTS InvoiceLine;  /* new for invoicing extension */
 DROP TABLE IF EXISTS Invoice;      /* new for invoicing extension */
 DROP TABLE IF EXISTS Booking;
 DROP TABLE IF EXISTS Car;
 DROP TABLE IF EXISTS CarModel;
 DROP TABLE IF EXISTS Paypal;
 DROP TABLE IF EXISTS CreditCard;
 DROP TABLE IF EXISTS BankAccount;
 DROP TABLE IF EXISTS PaymentMethod CASCADE;
 DROP TABLE IF EXISTS MemberPhone;
 DROP TABLE IF EXISTS Member        CASCADE;
 DROP TABLE IF EXISTS CarBay;
 DROP TABLE IF EXISTS Location;
 DROP TABLE IF EXISTS MembershipPlan;
 DROP DOMAIN IF EXISTS RegoType;
 DROP DOMAIN IF EXISTS PaymentNum;
 DROP DOMAIN IF EXISTS AmountInCents;
 DROP SCHEMA IF EXISTS CarSharing   CASCADE;
COMMIT;


/* schema starts here */
CREATE SCHEMA CarSharing;

/* this line will ensure that all following CREATE statements use the CarSharing schema */
/* it assumes that you have loaded our unidb schema from tutorial in week 6             */
SET search_Path = CarSharing, '$user', public, unidb;

/* we will keep all monetary data as integer values representing cents */
CREATE DOMAIN AmountInCents AS INTEGER CHECK (VALUE >= 0);
/* for Member and PayPal table */
CREATE DOMAIN EMailType AS VARCHAR(50) CHECK (value SIMILAR TO '[[:alnum:]_]+@[[:alnum:]]+%.[[:alnum:]]+');
/* for car registrations */
CREATE DOMAIN RegoType AS CHAR(6)      CHECK (value SIMILAR TO '[[:alnum:]]{6}');
/* for ratings */
CREATE DOMAIN RatingDomain AS SMALLINT CHECK ( VALUE BETWEEN 1 AND 5 );


CREATE TABLE MembershipPlan ( /* Note that all fees are in CENTS! */
   title         VARCHAR(20)   PRIMARY KEY,
   monthly_fee   AmountInCents NOT NULL, -- in cents!
   hourly_rate   AmountInCents NOT NULL, -- in cents!
   km_rate       AmountInCents NOT NULL, -- in cents!
   daily_rate    AmountInCents NOT NULL, -- in cents! for rents >= 12h, take this rate
   daily_km_rate AmountInCents NOT NULL, -- in cents! for rents >= 12h, km rate is reduced
   daily_km_included INTEGER   NOT NULL  --           for rents >= 12h, some km are free
);

CREATE TABLE Location (
   locID     INTEGER,
   name      VARCHAR(100) NOT NULL,
   type      VARCHAR(10)  NOT NULL,
   is_at     INTEGER      NULL,
   CONSTRAINT Location_PK      PRIMARY KEY (locID),
   CONSTRAINT Location_KEY     UNIQUE(name, is_at),
   CONSTRAINT Location_IsAt_FK FOREIGN KEY (is_at) REFERENCES Location(locID),
   CONSTRAINT Location_Type_CHK CHECK (type IN ('street','suburb','area','region','city','state','country'))
);

CREATE TABLE CarBay (
   bayID       SERIAL,              -- new surrogate key
   name        VARCHAR(80) NOT NULL,-- original identifier from E-R diagram
   address     VARCHAR(200),
   description TEXT,
   gps_lat     FLOAT,
   gps_long    FLOAT,
   mapURL      VARCHAR(200), -- this wasn't asked, but we have some data for Google-Maps URLs
   walkscore   INTEGER,      -- this wasn't asked, but cool to have, cf. www.walkscore.com
   located_at  INTEGER NOT NULL,
   CONSTRAINT CarBay_PK          PRIMARY KEY (bayID),
   CONSTRAINT CarBay_KEY         UNIQUE (name),
   CONSTRAINT CarBay_Location_FK FOREIGN KEY (located_at) REFERENCES Location(locID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Member (
   memberNo      INTEGER,                      -- new surrogate key to allow changeable email
   email         EMailType    NOT NULL UNIQUE, -- original key from E-R diagram
   nickname      VARCHAR(10)  NOT NULL UNIQUE, -- we require a nickname from everyone, good to be used for login
   password      VARCHAR(20)  NOT NULL,        -- better store just a hash value of the password
   pw_salt       VARCHAR(10),                  -- newly added for better security (not needed when bcrypt used)
   nameTitle     VARCHAR(10),
   nameGiven     VARCHAR(100),
   nameFamily    VARCHAR(100),
   address       VARCHAR(200),
   since         DATE         NOT NULL DEFAULT CURRENT_DATE,
   birthdate     DATE,
   licenseNo     BIGINT       NOT NULL UNIQUE, -- driver's license number
   licenseExp    DATE         NOT NULL,        -- expiry date of driver's license number
   homeBay       INTEGER      NULL,
   subscribed    VARCHAR(20)  NOT NULL,
   prefPaymentNo INTEGER      NOT NULL,  /* FK added later in script via ALTER TABLE */
   stat_nrOfBookings INTEGER DEFAULT 0,             /* ADDED: nr of bookings per member */
   stat_nrOfReviews  INTEGER DEFAULT 0,             /* ADDED: nr of reviews per member  */
   stat_sumPayments  AmountInCents DEFAULT 0,       /* ADDED: total member payments     */
   CONSTRAINT Member_PK            PRIMARY KEY (memberNo),
   CONSTRAINT Member_CarBay_FK     FOREIGN KEY (homeBay)    REFERENCES CarBay(bayID),
   CONSTRAINT Member_Membership_FK FOREIGN KEY (subscribed) REFERENCES MembershipPlan(title),
   CONSTRAINT Title_CHK CHECK (nameTitle IN ('Mr','Mrs','Ms','Dr','Prof'))
);

CREATE TABLE MemberPhone (
   memberNo   INTEGER,
   phone      VARCHAR(15),
   CONSTRAINT MemberPhone_PK PRIMARY KEY (memberNo,phone),
   CONSTRAINT MemberPhone_Member_FK FOREIGN KEY (memberNo) REFERENCES Member(memberNo) ON DELETE CASCADE
);

CREATE TABLE PaymentMethod (
   memberNo   INTEGER,
   methodNo   SMALLINT   DEFAULT 1,
   payType    VARCHAR(6) NOT NULL, -- new: short-cut helping us to find sub-class fast
   CONSTRAINT PaymentMethod_PK          PRIMARY KEY (memberNo, methodNo),
   CONSTRAINT PaymentMethod_Member_FK   FOREIGN KEY (memberNo) REFERENCES Member(memberNo) ON DELETE CASCADE,
   CONSTRAINT PaymentMethod_num_CHK     CHECK (methodNo between 1 and 3),
   CONSTRAINT PaymentMethod_payType_CHK CHECK (payType IN ('bank','ccard','paypal'))
);
ALTER TABLE Member
   ADD CONSTRAINT Member_PaymentMethod_FK FOREIGN KEY (memberNo, prefPaymentNo) REFERENCES PaymentMethod(memberNo, methodNo) ON DELETE NO ACTION ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE BankAccount (
   memberNo   INTEGER,
   methodNo   SMALLINT,
   acctName   VARCHAR(30) NOT NULL,
   acctNo     INTEGER     NOT NULL,
   bsb        CHAR(6)     NOT NULL,
   CONSTRAINT BankAccount_PK PRIMARY KEY (memberNo, methodNo),
   CONSTRAINT BankAccount_PaymentMethod_FK FOREIGN KEY (memberNo,methodNo) REFERENCES PaymentMethod(memberNo,methodNo)  ON DELETE CASCADE ON UPDATE CASCADE,
   CONSTRAINT BankAccount_BSB_CHK CHECK (bsb SIMILAR TO '[[:digit:]]{6}')
);

CREATE TABLE CreditCard (
   memberNo   INTEGER,
   methodNo   SMALLINT,
   brand      VARCHAR(6)  NOT NULL,
   cardName   VARCHAR(50) NOT NULL,
   cardNumber CHAR(16)    NOT NULL,
   expires    VARCHAR(5)  NOT NULL,   -- of format 'MM/YY'm see below
   CONSTRAINT CreditCard_PK               PRIMARY KEY (memberNo,methodNo),
   CONSTRAINT CreditCard_PaymentMethod_FK FOREIGN KEY (memberNo,methodNo) REFERENCES PaymentMethod(memberNo,methodNo)  ON DELETE CASCADE ON UPDATE CASCADE,
   CONSTRAINT CreditCard_Brand_CHK        CHECK (brand IN ('visa','master','amex')),
   CONSTRAINT CreditCard_ccNo_CHK         CHECK (cardNumber SIMILAR TO '[[:digit:]]{16}'),
   CONSTRAINT CreditCard_Expires_CHK      CHECK (expires SIMILAR TO '[[:digit:]][[:digit:]]/[[:digit:]][[:digit:]]')
);

CREATE TABLE PayPal (
   memberNo   INTEGER REFERENCES Member ON DELETE CASCADE,
   methodNo   SMALLINT,
   email      EMailType NOT NULL,
   CONSTRAINT PayPal_PK               PRIMARY KEY (memberNo,methodNo),
   CONSTRAINT PayPal_PaymentMethod_FK FOREIGN KEY (memberNo,methodNo) REFERENCES PaymentMethod(memberNo,methodNo)  ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE CarModel (
   make      VARCHAR(20),
   model     VARCHAR(20),
   category  VARCHAR(8)  NOT NULL,
   capacity  INTEGER,
   CONSTRAINT CarModel_PK           PRIMARY KEY (make, model),
   CONSTRAINT CarModel_category_CHK CHECK (category IN ('hatch','sedan','wagon','ute','van','minivan'))
);
CREATE TABLE Car (
   regno        RegoType,
   name         VARCHAR(40) NOT NULL,
   make         VARCHAR(20) NOT NULL,
   model        VARCHAR(20) NOT NULL,
   year         INTEGER,
   transmission VARCHAR(6),
   parkedAt     INTEGER     NOT NULL,
   CONSTRAINT Car_PK            PRIMARY KEY (regno),
   CONSTRAINT Car_KEY           UNIQUE      (name),
   CONSTRAINT Car_CarBay_FK     FOREIGN KEY (parkedAt)    REFERENCES CarBay(bayID) ON DELETE RESTRICT,
   CONSTRAINT Car_CarModel_FK   FOREIGN KEY (make, model) REFERENCES CarModel(make,model) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE Booking (
   bookingID   SERIAL,              -- new surrogate key; automatic increased integer ID
   car         RegoType   NOT NULL,
   madeBy      INTEGER    NOT NULL,
   whenBooked  TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
   startTime   TIMESTAMP  NOT NULL, -- start time is inclusive
   endTime     TIMESTAMP  NOT NULL, -- exclusive; booked time is the closed-open interval [startTime, endTime)
                                    -- according to E-R diagram, this would be duration instead
   CONSTRAINT Booking_PK          PRIMARY KEY (bookingID),
   CONSTRAINT Booking_KEY         UNIQUE      (car, startTime),
   CONSTRAINT Booking_Car_FK      FOREIGN KEY (car)    REFERENCES Car(regno),
   CONSTRAINT Booking_Member_FK   FOREIGN KEY (madeBy) REFERENCES Member(memberNo) ON DELETE CASCADE,
   CONSTRAINT Booking_isValid_CHK CHECK(endTime > startTime)
);

/*
 * Extension: Reviews
 */
CREATE TABLE Review (
   memberNo    INTEGER,
   regno       RegoType,
   whenDone    DATE         DEFAULT CURRENT_DATE,
   rating      RatingDomain NOT NULL,
   description VARCHAR(500),
   CONSTRAINT Review_PK        PRIMARY KEY (memberNo,regno), -- to allow multiple reviews per member, add 'whenDone'
   CONSTRAINT Review_Member_FK FOREIGN KEY (memberNo) REFERENCES Member ON DELETE CASCADE,
   CONSTRAINT Review_Cae_FK    FOREIGN KEY (regno)    REFERENCES Car    ON DELETE CASCADE
);
CREATE TABLE Rating (
   memberNo    INTEGER,
   reviewMem   INTEGER,
   reviewCar   RegoType,
   useful      RatingDomain NOT NULL,
   whenDone    DATE         DEFAULT CURRENT_DATE,
   CONSTRAINT Rating_PK        PRIMARY KEY (reviewMem, reviewCar, memberNo),
   CONSTRAINT Rating_Review_FK FOREIGN KEY (reviewMem, reviewCar) REFERENCES Review ON DELETE CASCADE,
   CONSTRAINT Rating_Member_FK FOREIGN KEY (memberNo)             REFERENCES Member ON DELETE CASCADE
);

/*
 * Extension: Invoicing
 */
CREATE TABLE Invoice (
   memberNo     INTEGER,
   invoiceNo    INTEGER,
   invoiceDate  DATE,
   monthlyFee   AmountInCents,     -- in cents
   totalAmount  AmountInCents,     -- in cents
   CONSTRAINT Invoice_PK        PRIMARY KEY (memberNo, invoiceNo),
   CONSTRAINT Invoice_Member_FK FOREIGN KEY (memberNo) REFERENCES Member ON DELETE RESTRICT
);
CREATE TABLE InvoiceLine (
   memberNo    INTEGER,
   invoiceNo   INTEGER,
   bookingId   INTEGER,
   distance    INTEGER,
   duration    INTEGER,
   timeCharge  AmountInCents NOT NULL,     -- in cents, charge for duration
   kmCharge    AmountInCents NOT NULL,     -- in cents, charge for distrance
   feeCharge   AmountInCents NOT NULL,     -- in cents, any late penalty etc
   CONSTRAINT InvoiceLine_PK         PRIMARY KEY (memberNo, invoiceNo, bookingId),
   CONSTRAINT InvoiceLine_Invoice_FK FOREIGN KEY (memberNo, invoiceNo) REFERENCES Invoice ON DELETE CASCADE,
   CONSTRAINT InvoiceLine_Booking_FK FOREIGN KEY (bookingId)           REFERENCES Booking ON DELETE CASCADE
);
CREATE TABLE Computer (
   id          INTEGER,
   installedIn RegoType,
   CONSTRAINT Computer_PK     PRIMARY KEY (id),
   CONSTRAINT Computer_KEY    UNIQUE      (installedIn),
   CONSTRAINT Computer_Car_FK FOREIGN KEY (installedIn) REFERENCES Car ON DELETE RESTRICT
);
CREATE TABLE TripLog (
   computer    INTEGER,
   tripNo      INTEGER,
   car         RegoType   NOT NULL,
   driver      INTEGER    NOT NULL,
   startTime   TIMESTAMP  NOT NULL, -- start time is inclusive
   endTime     TIMESTAMP  NOT NULL, -- exclusive; actual trip time is the closed-open interval [startTime, endTime)
   startOdo    INTEGER    NULL,     -- in actual data set can be NULL???
   distance    INTEGER    NOT NULL,  -- in km
   CONSTRAINT TipLog_PK          PRIMARY KEY (computer, tripNo),
   CONSTRAINT TipLog_Computer_FK FOREIGN KEY (computer) REFERENCES Computer,
   CONSTRAINT TipLog_Car_FK      FOREIGN KEY (car)      REFERENCES Car,
   CONSTRAINT TipLog_Member_FK   FOREIGN KEY (driver)   REFERENCES Member
);

/*
 * example trigger:
 * whenever a PaymentMethod gets deleted, then 'compress' the methodNo still in use
 */
CREATE FUNCTION PaymentMethodNoFixer() RETURNS trigger AS
$$
   BEGIN
      UPDATE PaymentMethod
         SET methodNo = methodNo - 1
       WHERE memberNo = OLD.memberNo
         AND methodNo > OLD.methodNo;
      RETURN OLD;
   END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER PaymentMethodDeleteTrigger
       AFTER DELETE ON PaymentMethod
       FOR EACH ROW
       WHEN ( OLD.methodNo < 3 )
       EXECUTE PROCEDURE PaymentMethodNoFixer();

/* end schema definition */


/* IMPORTANT TODO: */
/* please replace <your-login> with the name of your PostgreSQL login */
/* in the following ALTER USER username SET search_path ... command   */
/* this ensures that the carsharing schema is automatically used when you query one of its tables */
/* it assumes that you have loaded our unidb schema from tutorial in week 6             */
ALTER USER smcm8974 SET search_Path = '$user', public, unidb, carsharing;


/*
 * Some optional, more complex semantic integrity constraints
 */

/*
  -- guarantee disjoint Private- and Company-Accounts
  CREATE ASSERTION AssertDisjointPaymentMethods CHECK (
     NOT EXISTS ( SELECT memberNo, methodNo FROM BankAccount
                   INTERSECT
                  SELECT memberNo, methodNo FROM CreditCard
                   INTERSECT
                  SELECT memberNo, methodNo FROM PayPal )
  );
*/



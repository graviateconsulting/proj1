-- Parent Table: STOCKTRANSFERORDER
CREATE TABLE STOCKTRANSFERORDER (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    actualreceivedstore VARCHAR2(255),
    boxnumber VARCHAR2(255),
    createdby VARCHAR2(255),
    createddate TIMESTAMP,
    deliverymethod VARCHAR2(255),
    frontend VARCHAR2(255),
    lastupdatedby VARCHAR2(255),
    lastupdateddate TIMESTAMP,
    sourcepoint VARCHAR2(255),
    status VARCHAR2(255),
    storelocationidentifier VARCHAR2(255),
    transtype VARCHAR2(255),
    varianceindicator VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint)
);

-- Child Table: DELIVERYORDER_LIST
CREATE TABLE DELIVERYORDER_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    deliveryordernumber VARCHAR2(255),
    deliveryorderstatus VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

-- Child Table: NONSERIALIZEDMATERIAL_LIST
CREATE TABLE NONSERIALIZEDMATERIAL_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    materialcode VARCHAR2(255),
    quantity NUMBER,
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

-- Child Table: SERIALIZEDMATERIAL_LIST
CREATE TABLE SERIALIZEDMATERIAL_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    serialnumber VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

-- Child Table: STOLINEITEM_LIST
CREATE TABLE STOLINEITEM_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    lineitemid VARCHAR2(255),
    materialcode VARCHAR2(255),
    quantity NUMBER,
    uom VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);

-- Child Table: TRACKINGNUMBER_LIST
CREATE TABLE TRACKINGNUMBER_LIST (
    stonumber VARCHAR2(255) NOT NULL,
    destinationpoint VARCHAR2(255) NOT NULL,
    sequence_id NUMBER NOT NULL,
    trackingnumber VARCHAR2(255),
    PRIMARY KEY (stonumber, destinationpoint, sequence_id),
    FOREIGN KEY (stonumber, destinationpoint) REFERENCES STOCKTRANSFERORDER(stonumber, destinationpoint)
);
package com.tmobile.common

import org.joda.time.{DateTime, Minutes}
import scala.math._


//GetTimeCycle based on start time
object GetTimeCycle extends Enumeration {
  
        val today = new DateTime().withTimeAtStartOfDay();        
        val endDate = new DateTime();        
        val startDate = endDate.minusMinutes(15);
        
        
        //Generating the cycle no
        val cycle_no =
        if ( endDate.getDayOfMonth > startDate.getDayOfMonth) {
          95  
        } else {
          Minutes.minutesBetween(today, startDate).dividedBy(15).getMinutes
        }


        val fileFormat_date = "yyyyMMddHHmmss";                
        val file_date = startDate.toString(fileFormat_date);
        
        
        val date_format = "dd-MM-yyyy HH:mm:ss";        
        val start_date = startDate.toString(date_format);
        val end_date = endDate.toString(date_format);
        
        
        val date_cycleFormat = "yyyyMMdd";
        val date_cycle = startDate.toString(date_cycleFormat);
        
        
        //Function to get the eventhour or invocationhour
             def generateHoursList(x: Int): Seq[Int] = x match {
               case 1 => Seq(0,1)
               case 2 => Seq(1,2)
               case 3 => Seq(2,3)
               case 4 => Seq(3,4)
               case 5 => Seq(4,5)
               case 6 => Seq(5,6)
               case 7 => Seq(6,7)
               case 8 => Seq(7,8)
               case 9 => Seq(8,9)
               case 10 => Seq(9,10)
               case 11 => Seq(10,11)
               case 12 => Seq(11,12)
               case 13 => Seq(12,13)
               case 14 => Seq(13,14)
               case 15 => Seq(14,15)
               case 16 => Seq(15,16)
               case 17 => Seq(16,17)
               case 18 => Seq(17,18)
               case 19 => Seq(18,19)
               case 20 => Seq(19,20)
               case 21 => Seq(20,21)
               case 22 => Seq(21,22)
               case 23 => Seq(22,23)
               case _ => Seq(0,0)
             }
             

             
}

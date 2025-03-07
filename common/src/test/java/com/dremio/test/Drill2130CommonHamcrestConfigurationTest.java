/*
 * Copyright (C) 2017-2019 Dremio Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.dremio.test;

import static org.hamcrest.CoreMatchers.equalTo;
import static org.junit.Assert.assertThat;
import static org.junit.Assert.fail;

import org.junit.Test;

public class Drill2130CommonHamcrestConfigurationTest {

  @SuppressWarnings("unused")
  private org.hamcrest.MatcherAssert forCompileTimeCheckForNewEnoughHamcrest;

  @Test
  public void testJUnitHamcrestMatcherFailureWorks() {
    try {
      assertThat( 1, equalTo( 2 ) );
    }
    catch ( NoSuchMethodError e ) {
      fail( "Class search path seems broken re new JUnit and old Hamcrest."
             + "  Got NoSuchMethodError;  e: " + e );
    }
    catch ( AssertionError e ) {
      System.out.println( "Class path seems fine re new JUnit vs. old Hamcrest."
                          + " (Got AssertionError, not NoSuchMethodError.)" );
    }
  }

}

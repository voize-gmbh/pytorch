package de.voize.pytorch.suite;

import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import de.voize.pytorch.PytorchLiteInstrumentedTests;

@RunWith(Suite.class)
@Suite.SuiteClasses({PytorchLiteInstrumentedTests.class})
public class PytorchLiteInstrumentedTestSuite {}

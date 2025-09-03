package de.voize.pytorch.torchvision.suite;

import org.junit.runner.RunWith;
import org.junit.runners.Suite;
import de.voize.pytorch.torchvision.TorchVisionInstrumentedTests;

@RunWith(Suite.class)
@Suite.SuiteClasses({TorchVisionInstrumentedTests.class})
public class TorchVisionInstrumentedTestSuite {}

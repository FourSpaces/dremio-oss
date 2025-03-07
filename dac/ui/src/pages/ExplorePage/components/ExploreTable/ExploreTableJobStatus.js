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
import { Component } from 'react';
import PropTypes from 'prop-types';
import { connect } from 'react-redux';
import { withRouter } from 'react-router';
import { injectIntl } from 'react-intl';

import RealTimeTimer from '@app/components/RealTimeTimer';
import SampleDataMessage from '@app/pages/ExplorePage/components/SampleDataMessage';
import jobsUtils from '@app/utils/jobsUtils';
import {getJobProgress, getRunStatus, getImmutableTable, getExploreJobId, getJobOutputRecords} from '@app/selectors/explore';
import { cancelJobAndShowNotification } from '@app/actions/jobs/jobs';
import TooltipEnabledLabel from '@app/components/TooltipEnabledLabel';
import ExploreTableJobStatusMixin from 'dyn-load/pages/ExplorePage/components/ExploreTable/ExploreTableJobStatusMixin';

import './ExploreTableJobStatus.less';
import ExploreTableJobStatusDropdown from './ExploreTableJobStatusDropdown';
import ExploreTableJobStatusSpinner from './ExploreTableJobStatusSpinner';

export const JOB_STATUS = {
  notSubmitted: 'NOT_SUBMITTED',
  starting: 'STARTING',
  running: 'RUNNING',
  completed: 'COMPLETED',
  canceled: 'CANCELED',
  failed: 'FAILED',
  cancellationRequested: 'CANCELLATION_REQUESTED',
  enqueued: 'ENQUEUED',
  pending: 'PENDING',
  planning: 'PLANNING',
  metadataRetrieval: 'METADATA_RETRIEVAL',
  engineStart: 'ENGINE_START',
  queued: 'QUEUED',
  executionPlanning: 'EXECUTION_PLANNING'
};

export const isWorking = (status) => {
  return [
    JOB_STATUS.starting,
    JOB_STATUS.enqueued,
    JOB_STATUS.running,
    JOB_STATUS.cancellationRequested,
    JOB_STATUS.pending,
    JOB_STATUS.metadataRetrieval,
    JOB_STATUS.planning,
    JOB_STATUS.engineStart,
    JOB_STATUS.queued,
    JOB_STATUS.executionPlanning].includes(status);
};

@injectIntl
@ExploreTableJobStatusMixin
export class ExploreTableJobStatus extends Component {
  static propTypes = {
    approximate: PropTypes.bool,
    //connected
    jobProgress: PropTypes.object,
    runStatus: PropTypes.bool,
    jobId: PropTypes.string,
    haveRows: PropTypes.bool,
    outputRecords: PropTypes.number,
    cancelJob: PropTypes.func,
    intl: PropTypes.object.isRequired,
    //withRouter props
    location: PropTypes.object.isRequired
  };

  jobStatusNames = {
    [JOB_STATUS.notSubmitted]: la('Not Submitted'),
    [JOB_STATUS.starting]: la('Starting'),
    [JOB_STATUS.running]: la('Running'),
    [JOB_STATUS.completed]: la('Completed'),
    [JOB_STATUS.canceled]: la('Canceled'),
    [JOB_STATUS.failed]: la('Failed'),
    [JOB_STATUS.cancellationRequested]: la('Cancellation Requested'),
    [JOB_STATUS.enqueued]: la('Enqueued'),
    [JOB_STATUS.pending]: la('Pending'),
    [JOB_STATUS.metadataRetrieval]: la('Metadata Retrieval'),
    [JOB_STATUS.planning]: la('Planning'),
    [JOB_STATUS.engineStart]: la('Engine Start'),
    [JOB_STATUS.queued]: la('Queued'),
    [JOB_STATUS.executionPlanning]: la('Execution Planning')
  };

  constructor(props) {
    super(props);

    this.state = {
      displayJobTooltip: false
    };
  }

  doButtonAction = (actionType) => {
    const {cancelJob, jobProgress: {jobId}} = this.props;
    if (!jobId) return;

    if (actionType === 'cancel') {
      cancelJob(jobId);
    } //else ignore
  };

  renderTime = jobProgress => {
    // if not complete - show timer, else format end-start
    const { startTime, endTime } = jobProgress;
    if (isWorking(jobProgress.status)) {
      return (
        <RealTimeTimer
          startTime={startTime}
          formatter={jobsUtils.formatJobDuration}/>
      );
    } else if (startTime && endTime) {
      return jobsUtils.formatJobDuration(endTime - startTime);
    } else {
      return null;
    }
  };

  renderPreviewWarning = () => {
    //in case there was no jobProgress, show "preview" warning once table data appears
    const { approximate, haveRows } = this.props;
    if (approximate && haveRows) {
      return <>
        <SampleDataMessage />
        {this.renderExtraStatus(true)}
      </>;
    }
    return this.renderExtraStatus(true);
  };

  getCancellable = jobStatus => {
    return jobStatus === JOB_STATUS.running
      || jobStatus === JOB_STATUS.starting
      || jobStatus === JOB_STATUS.enqueued
      || jobStatus === JOB_STATUS.pending
      || jobStatus === JOB_STATUS.metadataRetrieval
      || jobStatus === JOB_STATUS.planning
      || jobStatus === JOB_STATUS.engineStart
      || jobStatus === JOB_STATUS.queued
      || jobStatus === JOB_STATUS.executionPlanning;
  };

  render() {
    const { jobProgress, runStatus, jobId, outputRecords, intl, cancelJob } = this.props;

    if (!jobProgress) {
      return this.renderPreviewWarning();
    }

    const jobTypeLabel = runStatus ? la('Run') : la('Preview');
    const isCompleteWithRecords = jobProgress.status === JOB_STATUS.completed && outputRecords;
    const isJobCancellable = this.getCancellable(jobProgress.status);
    const jobStatusLabel = (isCompleteWithRecords) ? la('Records: ') : la('Status: ');
    const jobStatusName = (isCompleteWithRecords) ? outputRecords.toLocaleString() : this.jobStatusNames[jobProgress.status];

    const helpContent = jobProgress.isRun ? intl.formatMessage({ id: 'Explore.run.warning' }) : intl.formatMessage({ id: 'Explore.preview.warning' });
    const jobLabel = (
      <span>
        <span className='exploreJobStatus__label'>{la('Job: ')}</span>
        <span style={styles.value}>{jobTypeLabel}</span>
      </span>
    );

    return (
      <div className='exploreJobStatus'>
        <TooltipEnabledLabel
          tooltip={helpContent}
          toolTipPosition={'bottom-start'}
          tooltipStyle={styles.helpTooltip}
          tooltipInnerStyle={styles.helpInnerTooltip}
          labelBefore
          label={jobLabel}
        />
        <span style={styles.divider}> | </span>

        <span className='exploreJobStatus__label'>{jobStatusLabel}</span>
        {!jobId && <span className='exploreJobStatus__name'>{jobStatusName}</span>}

        <ExploreTableJobStatusDropdown
          jobId ={jobId}
          jobStatusName={jobStatusName}
          isJobCancellable={isJobCancellable}
          cancelJob={cancelJob} />

        <ExploreTableJobStatusSpinner jobProgress={jobProgress} jobId={jobId}/>

        <span style={styles.divider}> | </span>
        <span className='exploreJobStatus__label'>{la('Time: ')}</span>
        <span style={styles.timeValue}>
          {this.renderTime(jobProgress)}
        </span>

        {this.renderExtraStatus()}
      </div>
    );
  }

}

function mapStateToProps(state, props) {
  const {approximate, location = {}} = props;
  const version = location.query && location.query.version;
  const jobProgress = getJobProgress(state, version);
  const runStatus = getRunStatus(state).isRun;
  const jobId = getExploreJobId(state);
  const outputRecords = getJobOutputRecords(state, version);

  let haveRows = false;
  // get preview tableData for preview w/o jobProgress
  if (!jobProgress && approximate) {
    const tableData = getImmutableTable(state, version);
    const rows = tableData.get('rows');
    haveRows = rows && !!rows.size;
  }

  return {
    jobProgress,
    runStatus,
    jobId,
    haveRows,
    outputRecords
  };
}

export default withRouter(connect(mapStateToProps, {
  cancelJob: cancelJobAndShowNotification
})(ExploreTableJobStatus));

export const styles = {
  wrapper: {
    display: 'flex',
    alignItems: 'center'
  },
  label: {
    display: 'inline-box',
    paddingRight: 3,
    fontWeight: 500
  },
  value: {
    display: 'inline-flex',
    alignItems: 'center'
  },
  timeValue: {
    minWidth: 10
  },
  divider: {
    display: 'inline-box',
    padding: '7px 5px',
    fontWeight: 500
  },
  textLink: {
    color: '#43B8C9',
    marginRight: 0
  },
  text: {
    marginRight: 6
  },
  helpTooltip: {
    zIndex: 10001
  },
  helpInnerTooltip: {
    width: 240
  },
  menuText: {
    marginRight: 0
  },
  defaultInnerStyle: {
    borderRadius: 5,
    padding: 10,
    width: 300
  }
};

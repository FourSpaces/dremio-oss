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
import Immutable from 'immutable';
import { Link } from 'react-router';

import EllipsedText from 'components/EllipsedText';
import jobsUtils from 'utils/jobsUtils';

import '@app/uiTheme/less/Acceleration/Acceleration.less';
import '@app/uiTheme/less/commonModifiers.less';
import Footprint from './Footprint';
import ValidityIndicator from './ValidityIndicator';
import Status from './Status';

export default class LayoutInfo extends Component {
  static propTypes = {
    layout: PropTypes.instanceOf(Immutable.Map),
    showValidity: PropTypes.bool,
    overrideTextMessage: PropTypes.string,
    className: PropTypes.any
  };

  renderBody() {
    if (this.props.overrideTextMessage) {
      return (
        <div data-qa='message' className={'LayoutInfo__message'}>
          {this.props.overrideTextMessage}
        </div>
      );
    }

    const reflection = this.props.layout.toJS();
    const marginRight = 10;

    const jobsURL = jobsUtils.navigationURLForLayoutId(reflection.id);
    return (
      <div className={`LayoutInfo__main ${this.props.className}`}>
        {this.props.showValidity && <div style={{marginRight, height: 20}}>
          <ValidityIndicator isValid={reflection && reflection.hasValidMaterialization}/>
        </div>}
        <div className={'LayoutInfo__status'}>
          <Link to={jobsURL} style={{height: 24}}><Status reflection={this.props.layout}/></Link>
        </div>
        <EllipsedText style={{flex: '1 1', marginRight}}>{/* todo: figure out how to @text for this */}
          <b>{la('Footprint: ')}</b>
          <Footprint currentByteSize={reflection.currentSizeBytes} totalByteSize={reflection.totalSizeBytes} />
        </EllipsedText>
        <div>
          <Link to={jobsURL}>{la('history')} »</Link>
        </div>
      </div>
    );
  }

  render() {
    if (!this.props.layout) return null;

    // todo: ax
    return <div className={`LayoutInfo__main ${this.props.className}`} >
      {this.renderBody()}
    </div>;
  }
}


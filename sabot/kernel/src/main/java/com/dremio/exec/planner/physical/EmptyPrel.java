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
package com.dremio.exec.planner.physical;

import java.io.IOException;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;

import org.apache.calcite.plan.RelOptCluster;
import org.apache.calcite.plan.RelOptCost;
import org.apache.calcite.plan.RelOptPlanner;
import org.apache.calcite.plan.RelTraitSet;
import org.apache.calcite.rel.AbstractRelNode;
import org.apache.calcite.rel.RelNode;
import org.apache.calcite.rel.RelWriter;
import org.apache.calcite.rel.metadata.RelMetadataQuery;
import org.apache.calcite.rel.type.RelDataType;

import com.dremio.exec.physical.base.PhysicalOperator;
import com.dremio.exec.physical.config.EmptyValues;
import com.dremio.exec.planner.physical.visitor.PrelVisitor;
import com.dremio.exec.record.BatchSchema;
import com.dremio.exec.record.BatchSchema.SelectionVectorMode;
import com.dremio.options.Options;
import com.dremio.options.TypeValidators.LongValidator;
import com.dremio.options.TypeValidators.PositiveLongValidator;

@Options
public class EmptyPrel extends AbstractRelNode implements Prel {

  public static final LongValidator RESERVE = new PositiveLongValidator("planner.op.empty.reserve_bytes", Long.MAX_VALUE, DEFAULT_RESERVE);
  public static final LongValidator LIMIT = new PositiveLongValidator("planner.op.empty.limit_bytes", Long.MAX_VALUE, DEFAULT_LIMIT);

  private final BatchSchema schema;

  public EmptyPrel(RelOptCluster cluster, RelTraitSet traitSet, RelDataType rowType, BatchSchema schema) {
    super(cluster, traitSet);
    this.schema = schema;
    this.rowType = rowType;
  }

  public BatchSchema getBatchSchema() {
    return schema;
  }

  @Override
  public RelNode copy(RelTraitSet traitSet, List<RelNode> inputs) {
    return new EmptyPrel(getCluster(), traitSet, getRowType(), schema);
  }

  @Override
  public RelWriter explainTerms(RelWriter pw) {
    return pw.item("schema", schema.toString());
  }

  @Override
  public RelOptCost computeSelfCost(RelOptPlanner planner, RelMetadataQuery mq) {
    return planner.getCostFactory().makeTinyCost();
  }

  @Override
  public Iterator<Prel> iterator() {
    return Collections.emptyIterator();
  }

  @Override
  public PhysicalOperator getPhysicalOperator(PhysicalPlanCreator creator) throws IOException {
    return new EmptyValues(creator.props(this, null, schema, RESERVE, LIMIT), schema);
  }

  @Override
  public <T, X, E extends Throwable> T accept(PrelVisitor<T, X, E> logicalVisitor, X value) throws E {
    return logicalVisitor.visitPrel(this, value);
  }

  @Override
  public SelectionVectorMode[] getSupportedEncodings() {
    return SelectionVectorMode.DEFAULT;
  }

  @Override
  public SelectionVectorMode getEncoding() {
    return SelectionVectorMode.NONE;
  }

  @Override
  public boolean needsFinalColumnReordering() {
    return false;
  }
}

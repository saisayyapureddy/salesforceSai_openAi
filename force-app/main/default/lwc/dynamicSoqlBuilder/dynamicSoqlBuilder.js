import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getObjectMetadata from '@salesforce/apex/DynamicSoqlController.getObjectMetadata';
import executeQuery from '@salesforce/apex/DynamicSoqlController.executeQuery';

export default class DynamicSoqlBuilder extends LightningElement {
    @track objectOptions = [
        { label: 'Account', value: 'Account' },
        { label: 'Contact', value: 'Contact' },
        { label: 'Lead', value: 'Lead' },
        { label: 'Opportunity', value: 'Opportunity' },
        { label: 'Case', value: 'Case' },
        { label: 'User', value: 'User' }
    ];

    @track fieldOptions = [];
    @track selectedObject = '';
    @track selectedFields = [];
    @track selectedObjectDescription = '';
    @track whereConditions = [];
    @track generatedQuery = 'SELECT Id FROM Account LIMIT 10';
    @track orderByField = '';
    @track sortDirection = 'ASC';
    @track limitValue = 10;
    @track offsetValue = 0;
    @track queryResults = [];
    @track tableColumns = [];
    @track recordCount = 0;

    // AI Insights
    @track performanceScore = 'Good';
    @track performanceScoreVariant = 'success';
    @track optimizationTips = [];
    @track queryExplanation = '';
    @track bestPracticeTip = '';

    // UI State
    @track showFieldSelection = false;
    @track showConditions = false;
    @track showAdditionalOptions = false;
    @track showInsights = false;

    // Options
    operatorOptions = [
        { label: 'Equals', value: '=' },
        { label: 'Not Equals', value: '!=' },
        { label: 'Less Than', value: '<' },
        { label: 'Less Than or Equal', value: '<=' },
        { label: 'Greater Than', value: '>' },
        { label: 'Greater Than or Equal', value: '>=' },
        { label: 'Like', value: 'LIKE' },
        { label: 'In', value: 'IN' },
        { label: 'Not In', value: 'NOT IN' }
    ];

    sortOptions = [
        { label: 'Ascending', value: 'ASC' },
        { label: 'Descending', value: 'DESC' }
    ];

    indexedFields = ['Id', 'Name', 'OwnerId', 'CreatedDate', 'LastModifiedDate', 'SystemModStamp'];
    conditionCounter = 0;

    connectedCallback() {
        this.generateDefaultQuery();
        this.updateAIInsights();
    }

    // Object Selection Handler
    async handleObjectChange(event) {
        this.selectedObject = event.target.value;
        this.selectedFields = [];
        this.whereConditions = [];
        this.orderByField = '';
        this.queryResults = [];

        if (this.selectedObject) {
            try {
                const metadata = await getObjectMetadata({ objectName: this.selectedObject });
                this.fieldOptions = metadata.fields.map(field => ({
                    label: field,
                    value: field,
                    isIndexed: this.indexedFields.includes(field)
                }));
                this.selectedObjectDescription = metadata.description;
                this.showFieldSelection = true;
                this.showConditions = true;
                this.showAdditionalOptions = true;
                this.generateQuery();
            } catch (error) {
                console.error('Error fetching object metadata:', error);
                this.showToast('Error', 'Failed to fetch object metadata', 'error');
            }
        } else {
            this.resetForm();
        }
    }

    // Field Selection Handlers
    handleFieldSelection(event) {
        const fieldName = event.target.dataset.field;
        if (event.target.checked) {
            this.selectedFields.push(fieldName);
        } else {
            this.selectedFields = this.selectedFields.filter(field => field !== fieldName);
        }
        this.generateQuery();
    }

    selectAllFields() {
        this.selectedFields = this.fieldOptions.map(field => field.value);
        this.updateCheckboxes();
        this.generateQuery();
    }

    clearAllFields() {
        this.selectedFields = [];
        this.updateCheckboxes();
        this.generateQuery();
    }

    updateCheckboxes() {
        const checkboxes = this.template.querySelectorAll('input[type="checkbox"]');
        checkboxes.forEach(checkbox => {
            checkbox.checked = this.selectedFields.includes(checkbox.dataset.field);
        });
    }

    // WHERE Condition Handlers
    addCondition() {
        const newCondition = {
            id: ++this.conditionCounter,
            field: '',
            operator: '=',
            value: '',
            logicOperator: 'AND',
            isFirst: this.whereConditions.length === 0
        };
        this.whereConditions.push(newCondition);
        this.generateQuery();
    }

    removeCondition(event) {
        const index = parseInt(event.target.dataset.index);
        this.whereConditions.splice(index, 1);
        // Update isFirst for the first condition
        if (this.whereConditions.length > 0) {
            this.whereConditions[0].isFirst = true;
        }
        this.generateQuery();
    }

    handleConditionChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.value;

        this.whereConditions[index][field] = value;
        this.generateQuery();
    }

    handleLogicOperatorChange(event) {
        const index = parseInt(event.target.dataset.index);
        this.whereConditions[index].logicOperator = event.target.value;
        this.generateQuery();
    }

    // Additional Options Handlers
    handleOrderByChange(event) {
        this.orderByField = event.target.value;
        this.generateQuery();
    }

    handleSortDirectionChange(event) {
        this.sortDirection = event.target.value;
        this.generateQuery();
    }

    handleLimitChange(event) {
        this.limitValue = event.target.value;
        if (this.limitValue > 50000) {
            this.showToast('Warning', 'LIMIT cannot exceed 50,000 records', 'warning');
            this.limitValue = 50000;
        }
        this.generateQuery();
    }

    handleOffsetChange(event) {
        this.offsetValue = event.target.value;
        this.generateQuery();
    }

    // Query Generation
    generateQuery() {
        if (!this.selectedObject) {
            this.generatedQuery = 'SELECT Id FROM Account LIMIT 10';
            return;
        }

        let query = 'SELECT ';

        // SELECT clause
        if (this.selectedFields.length > 0) {
            query += this.selectedFields.join(', ');
        } else {
            query += 'Id';
        }

        // FROM clause
        query += ` FROM ${this.selectedObject}`;

        // WHERE clause
        if (this.whereConditions.length > 0) {
            const conditions = this.whereConditions
                .filter(condition => condition.field && condition.value)
                .map((condition, index) => {
                    let conditionStr = '';
                    if (index > 0) {
                        conditionStr += ` ${condition.logicOperator} `;
                    }

                    let value = condition.value;
                    if (condition.operator === 'LIKE') {
                        value = `'%${value}%'`;
                    } else if (condition.operator === 'IN' || condition.operator === 'NOT IN') {
                        value = `(${value})`;
                    } else if (isNaN(value)) {
                        value = `'${value}'`;
                    }

                    conditionStr += `${condition.field} ${condition.operator} ${value}`;
                    return conditionStr;
                });

            if (conditions.length > 0) {
                query += ` WHERE ${conditions.join('')}`;
            }
        }

        // ORDER BY clause
        if (this.orderByField) {
            query += ` ORDER BY ${this.orderByField} ${this.sortDirection}`;
        }

        // LIMIT clause
        if (this.limitValue) {
            query += ` LIMIT ${this.limitValue}`;
        }

        // OFFSET clause
        if (this.offsetValue) {
            query += ` OFFSET ${this.offsetValue}`;
        }

        this.generatedQuery = query;
        this.updateAIInsights();
        this.showInsights = true;
    }

    generateDefaultQuery() {
        this.generatedQuery = 'SELECT Id FROM Account LIMIT 10';
    }

    // AI Insights
    updateAIInsights() {
        this.optimizationTips = [];
        let score = 'Good';
        let scoreVariant = 'success';

        // Check for indexed fields in WHERE clause
        const hasIndexedWhere = this.whereConditions.some(condition => 
            this.indexedFields.includes(condition.field) && condition.value
        );

        if (!hasIndexedWhere && this.whereConditions.length > 0) {
            this.optimizationTips.push('Use indexed fields in WHERE clause for better performance');
            score = 'Fair';
            scoreVariant = 'warning';
        }

        // Check for too many fields
        if (this.selectedFields.length > 10) {
            this.optimizationTips.push('Consider selecting only the fields you need');
        }

        // Check LIMIT
        if (!this.limitValue || this.limitValue > 10000) {
            this.optimizationTips.push('Use LIMIT to prevent hitting governor limits');
            if (score === 'Good') {
                score = 'Fair';
                scoreVariant = 'warning';
            }
        }

        // Check for negative operators
        const hasNegativeOperators = this.whereConditions.some(condition => 
            ['!=', 'NOT IN', 'NOT LIKE'].includes(condition.operator)
        );

        if (hasNegativeOperators) {
            this.optimizationTips.push('Negative operators can impact performance');
            score = 'Poor';
            scoreVariant = 'error';
        }

        this.performanceScore = score;
        this.performanceScoreVariant = scoreVariant;

        // Generate query explanation
        this.generateQueryExplanation();

        // Random best practice tip
        const bestPractices = [
            'Use indexed fields in WHERE clauses for better performance',
            'Limit the number of fields returned to only what you need',
            'Use LIMIT clause to prevent hitting governor limits',
            'Avoid SOQL queries inside loops',
            'Use selective filters to reduce result set size'
        ];
        this.bestPracticeTip = bestPractices[Math.floor(Math.random() * bestPractices.length)];
    }

    generateQueryExplanation() {
        if (!this.selectedObject) {
            this.queryExplanation = '';
            return;
        }

        let explanation = `This query retrieves `;

        if (this.selectedFields.length === 0) {
            explanation += 'the Id field ';
        } else if (this.selectedFields.length === 1) {
            explanation += `the ${this.selectedFields[0]} field `;
        } else {
            explanation += `${this.selectedFields.length} fields `;
        }

        explanation += `from ${this.selectedObject} records`;

        if (this.whereConditions.length > 0) {
            explanation += ' with filtering conditions';
        }

        if (this.orderByField) {
            explanation += ` sorted by ${this.orderByField}`;
        }

        if (this.limitValue) {
            explanation += ` limited to ${this.limitValue} records`;
        }

        explanation += '.';
        this.queryExplanation = explanation;
    }

    // Actions
    copyQuery() {
        navigator.clipboard.writeText(this.generatedQuery).then(() => {
            this.showToast('Success', 'Query copied to clipboard', 'success');
        }).catch(err => {
            console.error('Failed to copy: ', err);
            this.showToast('Error', 'Failed to copy query', 'error');
        });
    }

    async executeQuery() {
        if (!this.generatedQuery || !this.selectedObject) {
            this.showToast('Error', 'Please build a valid query first', 'error');
            return;
        }

        try {
            const result = await executeQuery({ query: this.generatedQuery });
            this.queryResults = result.records;
            this.recordCount = result.totalSize;

            // Generate table columns
            if (this.queryResults.length > 0) {
                const firstRecord = this.queryResults[0];
                this.tableColumns = Object.keys(firstRecord).map(field => ({
                    label: field,
                    fieldName: field,
                    type: typeof firstRecord[field] === 'number' ? 'number' : 'text'
                }));
            }

            this.showToast('Success', `Query executed successfully. Found ${this.recordCount} records.`, 'success');
        } catch (error) {
            console.error('Query execution error:', error);
            this.showToast('Error', `Query execution failed: ${error.body?.message || error.message}`, 'error');
        }
    }

    // Helper Methods
    resetForm() {
        this.fieldOptions = [];
        this.selectedFields = [];
        this.whereConditions = [];
        this.selectedObjectDescription = '';
        this.showFieldSelection = false;
        this.showConditions = false;
        this.showAdditionalOptions = false;
        this.showInsights = false;
        this.queryResults = [];
        this.generateDefaultQuery();
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
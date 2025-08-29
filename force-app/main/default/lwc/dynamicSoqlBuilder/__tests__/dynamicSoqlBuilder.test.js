import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllObjects from '@salesforce/apex/DynamicSoqlController.getAllObjects';
import getObjectMetadata from '@salesforce/apex/DynamicSoqlController.getObjectMetadata';
import executeQuery from '@salesforce/apex/DynamicSoqlController.executeQuery';
import analyzeQuery from '@salesforce/apex/DynamicSoqlController.analyzeQuery';
import getBestPractices from '@salesforce/apex/DynamicSoqlController.getBestPractices';

export default class DynamicSoqlBuilder extends LightningElement {
    @track objectOptions = [];
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
    @track isLoading = false;

    // AI Insights
    @track performanceScore = 85;
    @track performanceGrade = 'Good';
    @track performanceScoreVariant = 'success';
    @track optimizationTips = [];
    @track queryExplanation = '';
    @track bestPracticeTip = '';
    @track estimatedRecords = '';

    // UI State
    @track showFieldSelection = false;
    @track showConditions = false;
    @track showAdditionalOptions = false;
    @track showInsights = false;
    @track showResults = false;

    // Field metadata cache
    fieldMetadataCache = new Map();

    // Options
    operatorOptions = [
        { label: 'Equals (=)', value: '=' },
        { label: 'Not Equals (!=)', value: '!=' },
        { label: 'Less Than (<)', value: '<' },
        { label: 'Less Than or Equal (<=)', value: '<=' },
        { label: 'Greater Than (>)', value: '>' },
        { label: 'Greater Than or Equal (>=)', value: '>=' },
        { label: 'Like', value: 'LIKE' },
        { label: 'In', value: 'IN' },
        { label: 'Not In', value: 'NOT IN' }
    ];

    sortOptions = [
        { label: 'Ascending (A-Z)', value: 'ASC' },
        { label: 'Descending (Z-A)', value: 'DESC' }
    ];

    conditionCounter = 0;
    @track currentTipIndex = 0;
    @track allBestPractices = [];

    async connectedCallback() {
        this.isLoading = true;
        try {
            await this.loadObjects();
            await this.loadBestPractices();
            this.generateDefaultQuery();
            this.updateAIInsights();
            this.rotateTips();
        } catch (error) {
            console.error('Initialization error:', error);
            this.showToast('Error', 'Failed to initialize component', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Load all objects from Apex
    async loadObjects() {
        try {
            this.objectOptions = await getAllObjects();
            console.log('Loaded objects:', this.objectOptions.length);
        } catch (error) {
            console.error('Error loading objects:', error);
            this.showToast('Error', 'Failed to load Salesforce objects', 'error');
        }
    }

    // Load best practices
    async loadBestPractices() {
        try {
            this.allBestPractices = await getBestPractices();
            if (this.allBestPractices.length > 0) {
                this.bestPracticeTip = this.allBestPractices[0];
            }
        } catch (error) {
            console.error('Error loading best practices:', error);
        }
    }

    // Rotate tips every 10 seconds
    rotateTips() {
        setInterval(() => {
            if (this.allBestPractices.length > 0) {
                this.currentTipIndex = (this.currentTipIndex + 1) % this.allBestPractices.length;
                this.bestPracticeTip = this.allBestPractices[this.currentTipIndex];
            }
        }, 10000);
    }

    // Object Selection Handler
    async handleObjectChange(event) {
        this.selectedObject = event.target.value;
        this.selectedFields = [];
        this.whereConditions = [];
        this.orderByField = '';
        this.queryResults = [];
        this.recordCount = 0;
        this.showResults = false;
        this.fieldMetadataCache.clear();

        if (this.selectedObject) {
            this.isLoading = true;
            try {
                const metadata = await getObjectMetadata({ objectName: this.selectedObject });
                this.fieldOptions = metadata.fieldOptions;
                this.selectedObjectDescription = metadata.description;

                // Cache field metadata for quick access
                this.fieldOptions.forEach(field => {
                    this.fieldMetadataCache.set(field.value, field);
                });

                this.showFieldSelection = true;
                this.showConditions = true;
                this.showAdditionalOptions = true;
                this.generateQuery();
            } catch (error) {
                console.error('Error fetching object metadata:', error);
                this.showToast('Error', 'Failed to fetch object metadata: ' + error.body?.message, 'error');
            } finally {
                this.isLoading = false;
            }
        } else {
            this.resetForm();
        }
    }

    // Field Selection Handlers
    handleFieldSelection(event) {
        const fieldName = event.target.dataset.field;
        if (event.target.checked) {
            if (!this.selectedFields.includes(fieldName)) {
                this.selectedFields.push(fieldName);
            }
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
            if (checkbox.dataset.field) {
                checkbox.checked = this.selectedFields.includes(checkbox.dataset.field);
            }
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
            isFirst: this.whereConditions.length === 0,
            // Dynamic input properties
            inputType: 'text',
            isDateField: false,
            isPicklistField: false,
            isNumberField: false,
            isBooleanField: false,
            dateInputType: 'date',
            picklistOptions: [],
            booleanOptions: [
                { label: 'True', value: 'true' },
                { label: 'False', value: 'false' }
            ]
        };
        this.whereConditions = [...this.whereConditions, newCondition];
    }

    removeCondition(event) {
        const index = parseInt(event.target.dataset.index);
        this.whereConditions.splice(index, 1);
        // Update isFirst for the first condition
        if (this.whereConditions.length > 0) {
            this.whereConditions[0].isFirst = true;
        }
        // Force reactivity
        this.whereConditions = [...this.whereConditions];
        this.generateQuery();
    }

    async handleConditionChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.value;

        if (this.whereConditions[index]) {
            // Update the condition
            const updatedCondition = { ...this.whereConditions[index] };
            updatedCondition[field] = value;

            // When field changes, update the condition's input type and options
            if (field === 'field' && value) {
                const fieldMetadata = this.fieldMetadataCache.get(value);
                console.log('Field metadata for', value, ':', fieldMetadata);

                if (fieldMetadata) {
                    // Reset field type flags
                    updatedCondition.isDateField = false;
                    updatedCondition.isPicklistField = false;
                    updatedCondition.isNumberField = false;
                    updatedCondition.isBooleanField = false;

                    // Set the appropriate field type
                    if (fieldMetadata.isDate) {
                        updatedCondition.isDateField = true;
                        updatedCondition.inputType = fieldMetadata.type === 'DATETIME' ? 'datetime-local' : 'date';
                        updatedCondition.dateInputType = updatedCondition.inputType;
                        console.log('Set as date field with type:', updatedCondition.inputType);
                    } else if (fieldMetadata.isPicklist) {
                        updatedCondition.isPicklistField = true;
                        updatedCondition.inputType = 'picklist';
                        updatedCondition.picklistOptions = fieldMetadata.picklistValues || [];
                        console.log('Set as picklist field with options:', updatedCondition.picklistOptions);
                    } else if (fieldMetadata.isNumber) {
                        updatedCondition.isNumberField = true;
                        updatedCondition.inputType = 'number';
                        console.log('Set as number field');
                    } else if (fieldMetadata.isBoolean) {
                        updatedCondition.isBooleanField = true;
                        updatedCondition.inputType = 'boolean';
                        console.log('Set as boolean field');
                    } else {
                        updatedCondition.inputType = 'text';
                        console.log('Set as text field');
                    }

                    // Reset value when field changes
                    updatedCondition.value = '';
                }
            }

            // Update the condition in the array
            this.whereConditions[index] = updatedCondition;
            // Force reactivity
            this.whereConditions = [...this.whereConditions];

            this.generateQuery();
        }
    }

    handleLogicOperatorChange(event) {
        const index = parseInt(event.target.dataset.index);
        if (this.whereConditions[index]) {
            const updatedCondition = { ...this.whereConditions[index] };
            updatedCondition.logicOperator = event.target.value;
            this.whereConditions[index] = updatedCondition;
            this.whereConditions = [...this.whereConditions];
            this.generateQuery();
        }
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
            this.updateAIInsights();
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
                    const fieldMetadata = this.fieldMetadataCache.get(condition.field);

                    // Format value based on field type
                    if (fieldMetadata) {
                        if (fieldMetadata.isDate) {
                            // Date fields need specific formatting
                            if (fieldMetadata.type === 'DATETIME') {
                                value = value.replace('T', ' ') + ':00'; // Convert datetime-local to SOQL format
                            }
                            value = `${value}`;
                        } else if (condition.operator === 'LIKE') {
                            value = `'%${value}%'`;
                        } else if (condition.operator === 'IN' || condition.operator === 'NOT IN') {
                            // Handle IN operator - value should be comma-separated
                            const inValues = value.split(',').map(v => `'${v.trim()}'`).join(',');
                            value = `(${inValues})`;
                        } else if (fieldMetadata.isNumber) {
                            // Numbers don't need quotes
                            value = value;
                        } else if (fieldMetadata.isBoolean) {
                            // Boolean values
                            value = value.toLowerCase() === 'true' ? 'true' : 'false';
                        } else {
                            // Text fields need quotes
                            value = `'${value}'`;
                        }
                    } else {
                        // Fallback formatting
                        if (condition.operator === 'LIKE') {
                            value = `'%${value}%'`;
                        } else if (condition.operator === 'IN' || condition.operator === 'NOT IN') {
                            value = `(${value})`;
                        } else if (isNaN(value) && value !== 'true' && value !== 'false' && value !== 'null') {
                            value = `'${value}'`;
                        }
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
        this.updateAIInsights();
    }

    // AI Insights
    async updateAIInsights() {
        try {
            const analysis = await analyzeQuery({ query: this.generatedQuery });

            this.performanceScore = analysis.performanceScore;
            this.performanceGrade = analysis.performanceGrade;
            this.performanceScoreVariant = analysis.gradeVariant;
            this.optimizationTips = analysis.suggestions;
            this.queryExplanation = analysis.explanation;
            this.estimatedRecords = analysis.estimatedRecords;

        } catch (error) {
            console.error('Error analyzing query:', error);
            // Fallback to local analysis
            this.performanceScore = 75;
            this.performanceGrade = 'Good';
            this.performanceScoreVariant = 'success';
            this.optimizationTips = ['Query analysis temporarily unavailable'];
        }
    }

    // Actions
    copyQuery() {
        navigator.clipboard.writeText(this.generatedQuery).then(() => {
            this.showToast('Success', 'Query copied to clipboard! 📋', 'success');
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

        this.isLoading = true;
        try {
            const result = await executeQuery({ query: this.generatedQuery });
            this.queryResults = result.records;
            this.recordCount = result.totalSize;

            // Generate table columns with better field type detection
            if (this.queryResults.length > 0) {
                const firstRecord = this.queryResults[0];
                this.tableColumns = Object.keys(firstRecord).map(field => {
                    const fieldMetadata = this.fieldMetadataCache.get(field);
                    return {
                        label: field,
                        fieldName: field,
                        type: this.getTableColumnType(field, firstRecord[field], fieldMetadata)
                    };
                });
            }

            this.showResults = true;
            this.showToast('Success', `Query executed successfully! Found ${this.recordCount} records. ⚡`, 'success');

        } catch (error) {
            console.error('Query execution error:', error);
            this.showToast('Error', `Query execution failed: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    getTableColumnType(fieldName, value, fieldMetadata) {
        if (fieldMetadata) {
            if (fieldMetadata.isDate) {
                return fieldMetadata.type === 'DATETIME' ? 'date' : 'date-local';
            } else if (fieldMetadata.isNumber) {
                return 'number';
            } else if (fieldMetadata.isBoolean) {
                return 'boolean';
            }
        }

        // Fallback logic
        if (typeof value === 'number') {
            return 'number';
        } else if (fieldName.toLowerCase().includes('date')) {
            return 'date';
        } else if (fieldName.toLowerCase().includes('email')) {
            return 'email';
        } else if (fieldName.toLowerCase().includes('phone')) {
            return 'phone';
        } else if (fieldName.toLowerCase().includes('url') || fieldName.toLowerCase().includes('website')) {
            return 'url';
        } else {
            return 'text';
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
        this.showResults = false;
        this.queryResults = [];
        this.fieldMetadataCache.clear();
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

    // Getters for UI
    get hasQueryResults() {
        return this.queryResults && this.queryResults.length > 0;
    }

    get scoreProgressClass() {
        if (this.performanceScore >= 90) return 'progress-excellent';
        if (this.performanceScore >= 75) return 'progress-good';
        if (this.performanceScore >= 60) return 'progress-fair';
        return 'progress-poor';
    }

    get fieldSelectionOptions() {
        return this.fieldOptions.map(field => ({
            ...field,
            fieldId: `field-${field.value}`
        }));
    }

    get hasOptimizationTips() {
        return this.optimizationTips && this.optimizationTips.length > 0;
    }
}